const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const layout = @import("layout.zig");

const InodeLayout = layout.InodeLayout;
const BlockGroupLayout = layout.BlockGroupLayout;

const Inode = @import("../types/inode.zig").Inode;
const BlockGroup = @import("../types/block_group.zig").BlockGroup;
const addressing = @import("addressing.zig");

pub const Reader = struct {
    // Fields
    allocator: Allocator,
    file: fs.File,
    block_size: u32,

    // Lifecycle
    pub fn init(allocator: Allocator, file: fs.File, block_size: u32) Reader {
        return Reader{
            .allocator = allocator,
            .file = file,
            .block_size = block_size,
        };
    }

    // Public
    pub fn readAt(self: *const Reader, offset: u64, buffer: []u8) !usize {
        try self.file.seekTo(offset);
        return try self.file.read(buffer);
    }

    pub fn readAlloc(self: *const Reader, offset: u64, size: usize) ![]u8 {
        const buffer = try self.allocator.alloc(u8, size);
        errdefer self.allocator.free(buffer);

        const bytes_read = try self.readAt(offset, buffer);
        if (bytes_read != size) {
            self.allocator.free(buffer);
            return error.ReadError;
        }

        return buffer;
    }

    pub fn readStruct(self: *const Reader, comptime T: type, offset: u64) !T {
        try self.file.seekTo(offset);

        var result: T = undefined;
        const bytes_read = try self.file.read(std.mem.asBytes(&result));

        if (bytes_read != @sizeOf(T)) {
            return error.ReadError;
        }

        return result;
    }

    pub fn readInodeAt(self: *const Reader, offset: u64) !Inode {
        const inode_layout = try self.readStruct(InodeLayout, offset);
        return Inode{ .layout = inode_layout };
    }

    pub fn readBlockGroupAt(self: *const Reader, offset: u64) !BlockGroup {
        const bgd_layout = try self.readStruct(BlockGroupLayout, offset);
        return BlockGroup{ .layout = bgd_layout };
    }

    pub fn readBlock(self: *const Reader, block_number: u64) ![]u8 {
        const offset = block_number * self.block_size;
        return try self.readAlloc(offset, self.block_size);
    }

    pub fn readBlocks(self: *const Reader, start_block: u64, block_count: u32) ![]u8 {
        const offset = start_block * self.block_size;
        const total_size = block_count * self.block_size;
        return try self.readAlloc(offset, total_size);
    }

    pub fn readInodeByNumber(self: *const Reader, inode_number: u32, inodes_per_group: u32, inode_size: u32) !Inode {
        if (inode_number == 0) {
            return error.InvalidInodeNumber;
        }

        const block_group = addressing.inodeToBlockGroup(inode_number, inodes_per_group);
        const group_index = addressing.inodeToGroupIndex(inode_number, inodes_per_group);

        const bgd_offset = addressing.blockGroupDescriptorOffset(block_group, self.block_size);
        const bgd = try self.readBlockGroupAt(bgd_offset);

        const inode_offset = addressing.inodeTableOffset(
            bgd.inodeTableBlock(),
            group_index,
            inode_size,
            self.block_size,
        );

        return try self.readInodeAt(inode_offset);
    }
};
