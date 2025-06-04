const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Superblock = @import("structures/superblock.zig").Superblock;
const Inode = @import("structures/inode.zig").Inode;
const BlockGroup = @import("structures/block_group.zig").BlockGroup;
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

    pub fn getEntry(self: *Ext4FileSystem, allocator: Allocator, path: []const u8) !Entry {
        // TODO: Implement path finding
        _ = self;
        _ = allocator;
        _ = path;
        return errors.FileSystemError.ReadError;
    }

    pub fn readFile(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]u8 {
        // TODO: Implement file reading
        _ = self;
        _ = allocator;
        _ = entry;
        return errors.FileSystemError.ReadError;
    }

    pub fn listDirectory(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]Entry {
        // TODO: Implement directory listing
        _ = self;
        _ = allocator;
        _ = entry;
        return errors.FileSystemError.ReadError;
    }
};
