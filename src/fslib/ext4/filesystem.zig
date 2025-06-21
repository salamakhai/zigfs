const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Superblock = @import("structures/superblock.zig").Superblock;
const Inode = @import("structures/inode.zig").Inode;
const BlockGroup = @import("structures/block_group.zig").BlockGroup;
const Ext4DirEntry = @import("structures/dir_entry.zig").Ext4DirEntry;
const ExtentHeader = @import("structures/extent.zig").ExtentHeader;
const Extent = @import("structures/extent.zig").Extent;
const Entry = @import("../entry.zig").Entry;
const EntryType = @import("../entry.zig").EntryType;
const errors = @import("../errors.zig");

pub const Ext4FileSystem = struct {
    file: fs.File,
    superblock: Superblock,
    allocator: Allocator,
    block_size: u32,

    pub fn init(
        allocator: Allocator,
        file: fs.File,
    ) !*Ext4FileSystem {
        var superblock = try Superblock.fromFile(file);

        const image = try allocator.create(Ext4FileSystem);
        image.* = Ext4FileSystem{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
            .block_size = superblock.blockSize(),
        };

        return image;
    }

    pub fn deinit(self: *Ext4FileSystem) void {
        self.file.close();
        self.allocator.destroy(self);
    }

    pub fn readInode(self: *Ext4FileSystem, inode_number: u32) !Inode {
        if (inode_number == 0) {
            // Inode 0 is invalid
            return errors.FileSystemError.ReadError;
        }

        // Calculate which block group contains this inode
        const group_number = (inode_number - 1) / self.superblock.s_inodes_per_group;
        const inode_index = (inode_number - 1) % self.superblock.s_inodes_per_group;

        // Read block group descriptor (starts after superblock)
        const bgd_table_block = if (self.block_size == 1024) @as(u64, 2) else @as(u64, 1);
        const bgd_offset = (bgd_table_block * self.block_size) + (group_number * @sizeOf(BlockGroup));
        try self.file.seekTo(bgd_offset);

        var bgd: BlockGroup = undefined;
        const read_bytes = try self.file.read(std.mem.asBytes(&bgd));
        if (read_bytes < @sizeOf(BlockGroup)) {
            return errors.FileSystemError.ReadError;
        }

        // Calculate inode offset within the inode table
        const inode_table_block = bgd.inodeTableBlock();
        const inode_size = if (self.superblock.s_rev_level >= 1) @as(u32, 256) else @as(u32, 128);
        const inode_offset = (inode_table_block * self.block_size) + (inode_index * inode_size);

        try self.file.seekTo(inode_offset);

        var inode: Inode = undefined;
        const inode_read_bytes = try self.file.read(std.mem.asBytes(&inode));
        if (inode_read_bytes < @sizeOf(Inode)) {
            return errors.FileSystemError.ReadError;
        }

        return inode;
    }

    /// Find an entry by name within a directory inode
    fn findEntryInDirectory(self: *Ext4FileSystem, allocator: Allocator, dir_inode: *const Inode, entry_name: []const u8) !u32 {
        if (!dir_inode.isDirectory()) {
            return errors.FileSystemError.NotDirectory;
        }

        // Read the directory data
        const dir_data = try self.readInodeData(allocator, dir_inode);
        defer allocator.free(dir_data);

        // Parse directory entries to find the requested entry
        var offset: usize = 0;
        while (offset < dir_data.len) {
            // Ensure we have enough data for the directory entry header
            if (offset + @sizeOf(Ext4DirEntry) > dir_data.len) {
                break;
            }

            // Read the directory entry safely
            var dir_entry: Ext4DirEntry = undefined;
            const entry_bytes = std.mem.asBytes(&dir_entry);
            const available_bytes = @min(entry_bytes.len, dir_data.len - offset);
            @memcpy(entry_bytes[0..available_bytes], dir_data[offset .. offset + available_bytes]);

            // Validate the entry
            if (!dir_entry.isValid() or dir_entry.record_len == 0) {
                break;
            }

            // Check if this entry extends beyond our data
            if (offset + dir_entry.record_len > dir_data.len) {
                break;
            }

            // Skip deleted entries (inode == 0)
            if (dir_entry.inode != 0) {
                // Get the name
                const name = dir_entry.getName(dir_data, offset);

                // Check if this is the entry we're looking for
                if (std.mem.eql(u8, name, entry_name)) {
                    return dir_entry.inode;
                }
            }

            // Move to next entry
            offset = dir_entry.nextEntry(offset);
        }

        return errors.FileSystemError.EntryNotFound;
    }

    pub fn getRootInode(self: *Ext4FileSystem) !Inode {
        // Root directory is always inode 2 in ext4
        return self.readInode(2);
    }

    pub fn getRootEntry(self: *Ext4FileSystem, allocator: Allocator) !Entry {
        const root_inode = try self.getRootInode();
        const root_name = try allocator.dupe(u8, "/");

        return Entry{
            .name = root_name,
            .entry_type = if (root_inode.isDirectory()) .directory else .file,
            .size = root_inode.size(),
            .mode = root_inode.i_mode,
            .inode_number = 2,
        };
    }

    /// Read data blocks from an inode
    pub fn readInodeData(self: *Ext4FileSystem, allocator: Allocator, inode: *const Inode) ![]u8 {
        const file_size = inode.size();

        if (file_size == 0) {
            return try allocator.alloc(u8, 0);
        }

        const data = try allocator.alloc(u8, @intCast(file_size));
        try self.readExtentData(data, inode);

        return data;
    }

    /// Read data using extent tree
    fn readExtentData(self: *Ext4FileSystem, data: []u8, inode: *const Inode) !void {
        // The extent tree root is stored in i_block
        const extent_data = std.mem.asBytes(&inode.i_block);
        const header = @as(*const ExtentHeader, @ptrCast(@alignCast(extent_data.ptr)));

        if (!header.isValid()) {
            return errors.FileSystemError.ReadError;
        }

        if (header.isLeaf()) {
            // This is a leaf node, read extents directly
            const extents_start = @sizeOf(ExtentHeader);
            var i: u16 = 0;
            while (i < header.eh_entries) : (i += 1) {
                const extent_offset = extents_start + i * @sizeOf(Extent);
                const extent = @as(*const Extent, @ptrCast(@alignCast(&extent_data[extent_offset])));

                // Read this extent
                const physical_block = extent.startBlock();
                const block_offset = physical_block * self.block_size;
                const extent_size = @as(usize, extent.length()) * self.block_size;
                const logical_offset = @as(usize, extent.logicalBlock()) * self.block_size;

                // Don't read beyond file size
                const bytes_to_read = @min(extent_size, data.len - logical_offset);
                if (logical_offset + bytes_to_read > data.len) {
                    return errors.FileSystemError.ReadError;
                }

                try self.file.seekTo(block_offset);
                const read_bytes = try self.file.read(data[logical_offset .. logical_offset + bytes_to_read]);

                if (read_bytes != bytes_to_read) {
                    return errors.FileSystemError.ReadError;
                }
            }
        } else {
            // TODO: Handle non-leaf nodes
            return errors.FileSystemError.ReadError;
        }
    }

    pub fn getEntry(self: *Ext4FileSystem, allocator: Allocator, path: []const u8) !Entry {
        // Handle root directory
        if (std.mem.eql(u8, path, "/")) {
            return self.getRootEntry(allocator);
        }

        // Handle empty path as root
        if (path.len == 0) {
            return self.getRootEntry(allocator);
        }

        // Validate path length
        if (path.len > 4096) {
            return errors.FileSystemError.EntryNotFound; // Path too long
        }

        // Split path into components, skipping empty components
        var path_components = std.ArrayList([]const u8).init(allocator);
        defer path_components.deinit();

        var iter = std.mem.splitScalar(u8, path, '/');
        while (iter.next()) |component| {
            if (component.len > 0) {
                try path_components.append(component);
            }
        }

        // Start from root directory
        var current_inode = try self.getRootInode();
        var current_name = try allocator.dupe(u8, "/");
        var current_inode_number: u32 = 2; // Root inode is always 2

        // Traverse path components
        for (path_components.items) |component| {
            // Ensure current entry is a directory
            if (!current_inode.isDirectory()) {
                allocator.free(current_name);
                return errors.FileSystemError.NotDirectory;
            }

            // Find the component in the current directory
            current_inode_number = self.findEntryInDirectory(allocator, &current_inode, component) catch |err| {
                allocator.free(current_name);
                return switch (err) {
                    error.EntryNotFound => errors.FileSystemError.EntryNotFound,
                    error.NotDirectory => errors.FileSystemError.NotDirectory,
                    else => err,
                };
            };

            // Read the found entry's inode
            current_inode = self.readInode(current_inode_number) catch |err| {
                allocator.free(current_name);
                return err;
            };

            // Handle symbolic link resolution
            if (current_inode.isSymlink()) {
                // TODO: Implement symbolic link resolution
            }

            // Update current name (free previous, allocate new)
            allocator.free(current_name);
            current_name = try allocator.dupe(u8, component);
        }

        // Create entry from final inode
        const entry_type: EntryType =
            if (current_inode.isDirectory())
                .directory
            else if (current_inode.isRegularFile())
                .file
            else if (current_inode.isSymlink())
                .symlink
            else
                .unknown;

        return Entry{
            .name = current_name,
            .entry_type = entry_type,
            .size = current_inode.size(),
            .mode = current_inode.i_mode,
            .inode_number = current_inode_number,
        };
    }

    pub fn readFile(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]u8 {
        if (!entry.isFile()) {
            return errors.FileSystemError.ReadError;
        }

        const file_inode = try self.readInode(entry.inode_number);
        return self.readInodeData(allocator, &file_inode);
    }

    pub fn listDirectory(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]Entry {
        if (!entry.isDirectory()) {
            return errors.FileSystemError.NotDirectory;
        }

        // Get the directory inode using the inode number stored in the entry
        const dir_inode = try self.readInode(entry.inode_number);

        // Read the directory data
        const dir_data = try self.readInodeData(allocator, &dir_inode);
        defer allocator.free(dir_data);

        // Parse directory entries
        var entries = std.ArrayList(Entry).init(allocator);
        var offset: usize = 0;

        while (offset < dir_data.len) {
            // Ensure we have enough data for the directory entry header
            if (offset + @sizeOf(Ext4DirEntry) > dir_data.len) {
                break;
            }

            // Read the directory entry safely
            var dir_entry: Ext4DirEntry = undefined;
            const entry_bytes = std.mem.asBytes(&dir_entry);
            const available_bytes = @min(entry_bytes.len, dir_data.len - offset);

            @memcpy(
                entry_bytes[0..available_bytes],
                dir_data[offset .. offset + available_bytes],
            );

            // Validate the entry
            if (!dir_entry.isValid() or dir_entry.record_len == 0) {
                break;
            }

            // Check if this entry extends beyond data
            if (offset + dir_entry.record_len > dir_data.len) {
                break;
            }

            // Skip deleted entries (inode == 0)
            if (dir_entry.inode != 0) {
                // Get the name
                const name = dir_entry.getName(dir_data, offset);

                // Create entry with enhanced information
                var filesystem_entry = try dir_entry.toEntry(name, allocator);
                filesystem_entry.inode_number = dir_entry.inode;

                // Try to read the inode to get size and mode information
                if (self.readInode(dir_entry.inode)) |inode| {
                    filesystem_entry.size = inode.size();
                    filesystem_entry.mode = inode.i_mode;
                } else |_| {
                    filesystem_entry.size = 0;
                    filesystem_entry.mode = 0;
                }

                try entries.append(filesystem_entry);
            }

            // Move to next entry
            offset = dir_entry.nextEntry(offset);
        }

        return entries.toOwnedSlice();
    }
};
