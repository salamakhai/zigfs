const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Superblock = @import("../structures/superblock.zig").Superblock;
const Inode = @import("../structures/inode.zig").Inode;
const BlockGroup = @import("../structures/block_group.zig").Ext4BlockGroup;
const ExtentHeader = @import("../structures/extent.zig").ExtentHeader;
const Extent = @import("../structures/extent.zig").Extent;
const errors = @import("../../errors.zig");

pub const Reader = struct {
    file: fs.File,
    superblock: *const Superblock,
    block_size: u32,

    pub fn init(file: fs.File, superblock: *const Superblock) Reader {
        return Reader{
            .file = file,
            .superblock = superblock,
            .block_size = superblock.blockSize(),
        };
    }

    pub fn readInode(self: *const Reader, inode_number: u32) !Inode {
        if (inode_number == 0) {
            return errors.FileSystemError.ReadError;
        }

        const group_number = (inode_number - 1) / self.superblock.s_inodes_per_group;
        const inode_index = (inode_number - 1) % self.superblock.s_inodes_per_group;

        const bgd_table_block = if (self.block_size == 1024) @as(u64, 2) else @as(u64, 1);
        const bgd_offset = (bgd_table_block * self.block_size) + (group_number * @sizeOf(BlockGroup));
        try self.file.seekTo(bgd_offset);

        var bgd: BlockGroup = undefined;
        const read_bytes = try self.file.read(std.mem.asBytes(&bgd));
        if (read_bytes < @sizeOf(BlockGroup)) {
            return errors.FileSystemError.ReadError;
        }

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

    pub fn readInodeData(self: *const Reader, allocator: Allocator, inode: *const Inode) ![]u8 {
        const file_size = inode.size();

        if (file_size == 0) {
            return try allocator.alloc(u8, 0);
        }

        const data = try allocator.alloc(u8, @intCast(file_size));
        try self.readExtentData(data, inode);

        return data;
    }

    fn readExtentData(self: *const Reader, data: []u8, inode: *const Inode) !void {
        const extent_data = std.mem.asBytes(&inode.i_block);
        const header = @as(*const ExtentHeader, @ptrCast(@alignCast(extent_data.ptr)));

        if (!header.isValid()) {
            return errors.FileSystemError.ReadError;
        }

        if (header.isLeaf()) {
            const extents_start = @sizeOf(ExtentHeader);
            var i: u16 = 0;
            while (i < header.eh_entries) : (i += 1) {
                const extent_offset = extents_start + i * @sizeOf(Extent);
                const extent = @as(*const Extent, @ptrCast(@alignCast(&extent_data[extent_offset])));

                const physical_block = extent.startBlock();
                const block_offset = physical_block * self.block_size;
                const extent_size = @as(usize, extent.length()) * self.block_size;
                const logical_offset = @as(usize, extent.logicalBlock()) * self.block_size;

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
            return errors.FileSystemError.ReadError;
        }
    }
};