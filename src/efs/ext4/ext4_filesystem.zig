const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Superblock = @import("structures/superblock.zig").Superblock;
const Inode = @import("structures/inode.zig").Inode;
const BlockGroup = @import("structures/block_group.zig").BlockGroup;
const Ext4DirEntry = @import("structures/dir_entry.zig").Ext4DirEntry;
const ExtentHeader = @import("structures/extent.zig").ExtentHeader;
const Extent = @import("structures/extent.zig").Extent;
const EXT4_EXTENTS_FL = @import("structures/extent.zig").EXT4_EXTENTS_FL;
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
            return errors.FileSystemError.ReadError; // Inode 0 is invalid
        }

        // Calculate which block group contains this inode
        const group_number = (inode_number - 1) / self.superblock.s_inodes_per_group;
        const inode_index = (inode_number - 1) % self.superblock.s_inodes_per_group;

        // Read block group descriptor (BGD starts after superblock)
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

    pub fn getRootInode(self: *Ext4FileSystem) !Inode {
        return self.readInode(2); // Root directory is always inode 2 in ext4
    }

    pub fn getRootEntry(self: *Ext4FileSystem, allocator: Allocator) !Entry {
        _ = allocator; // Will use for name allocation later
        const root_inode = try self.getRootInode();

        return Entry{
            .name = "/",
            .entry_type = if (root_inode.isDirectory()) .directory else .file,
            .size = root_inode.size(),
            .mode = root_inode.i_mode,
        };
    }

    /// Read data blocks from an inode (handles both direct blocks and extents)
    pub fn readInodeData(self: *Ext4FileSystem, allocator: Allocator, inode: *const Inode) ![]u8 {
        const file_size = inode.size();

        if (file_size == 0) {
            return try allocator.alloc(u8, 0);
        }

        var data = try allocator.alloc(u8, @intCast(file_size));

        if (inode.i_flags & EXT4_EXTENTS_FL != 0) {
            // Handle extent-based storage
            try self.readExtentData(data, inode);
        } else {
            // Handle direct/indirect blocks (legacy format)
            var bytes_read: usize = 0;

            for (inode.i_block[0..12]) |block_num| {
                if (block_num == 0) break; // No more blocks

                const block_offset = @as(u64, block_num) * self.block_size;
                try self.file.seekTo(block_offset);

                const bytes_to_read = @min(self.block_size, @as(u32, @intCast(file_size - bytes_read)));
                const read_bytes = try self.file.read(data[bytes_read .. bytes_read + bytes_to_read]);

                if (read_bytes != bytes_to_read) {
                    allocator.free(data);
                    return errors.FileSystemError.ReadError;
                }

                bytes_read += read_bytes;
                if (bytes_read >= file_size) break;
            }
        }

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
            // This is an internal node - would need to read child nodes
            // For now, return error as this is more complex
            return errors.FileSystemError.ReadError;
        }
    }

    pub fn getEntry(self: *Ext4FileSystem, allocator: Allocator, path: []const u8) !Entry {
        // For now, only support root directory
        if (std.mem.eql(u8, path, "/")) {
            return self.getRootEntry(allocator);
        }

        // TODO: Implement full path resolution for subdirectories
        return errors.FileSystemError.EntryNotFound;
    }

    pub fn readFile(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]u8 {
        // TODO: Implement file reading
        _ = self;
        _ = allocator;
        _ = entry;
        return errors.FileSystemError.ReadError;
    }

    pub fn listDirectory(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]Entry {
        if (!entry.isDirectory()) {
            return errors.FileSystemError.NotDirectory;
        }

        // For now, only support root directory
        if (!std.mem.eql(u8, entry.name, "/")) {
            return errors.FileSystemError.ReadError; // Not implemented for other directories yet
        }

        // Get the root directory inode
        const root_inode = try self.getRootInode();

        // Read the directory data
        const dir_data = try self.readInodeData(allocator, &root_inode);
        defer allocator.free(dir_data);

        // Parse directory entries
        var entries = std.ArrayList(Entry).init(allocator);
        var offset: usize = 0;

        while (offset < dir_data.len) {
            // Ensure we have enough data for the directory entry header
            if (offset + @sizeOf(Ext4DirEntry) > dir_data.len) {
                break;
            }

            // Read the directory entry
            const dir_entry = @as(*const Ext4DirEntry, @ptrCast(@alignCast(&dir_data[offset])));

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

                // Skip "." and ".." entries for cleaner output
                if (!std.mem.eql(u8, name, ".") and !std.mem.eql(u8, name, "..")) {
                    // Create entry with enhanced information
                    var filesystem_entry = try dir_entry.toEntry(name, allocator);

                    // Try to read the inode to get size and mode information
                    if (self.readInode(dir_entry.inode)) |inode| {
                        filesystem_entry.size = inode.size();
                        filesystem_entry.mode = inode.i_mode;
                    } else |_| {
                        // If we can't read the inode, use defaults
                        filesystem_entry.size = 0;
                        filesystem_entry.mode = 0;
                    }

                    try entries.append(filesystem_entry);
                }
            }

            // Move to next entry
            offset = dir_entry.nextEntry(offset);
        }

        return entries.toOwnedSlice();
    }
};
