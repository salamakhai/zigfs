const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const EXT4_SUPER_MAGIC: u16 = 0xEF53;
pub const SUPERBLOCK_OFFSET: u64 = 1024;
pub const EXT4_MIN_BLOCK_SIZE: u32 = 1024;
pub const EXT4_DEFAULT_BLOCK_SIZE: u32 = 4096;

pub const ImageError = error{
    InvalidMagicNumber,
    ReadError,
    NotExt4Format,
    InvalidBlockSize,
    OutOfBounds,
};

/// Structure representing ext4 superblock fields
pub const Ext4Superblock = struct {
    s_inodes_count: u32,
    s_blocks_count_lo: u32,
    s_r_blocks_count_lo: u32,
    s_free_blocks_count_lo: u32,
    s_free_inodes_count: u32,
    s_first_data_block: u32,
    s_log_block_size: u5,
    s_log_cluster_size: u32,
    s_blocks_per_group: u32,
    s_clusters_per_group: u32,
    s_inodes_per_group: u32,
    s_mtime: u32,
    s_wtime: u32,
    s_mnt_count: u16,
    s_max_mnt_count: u16,
    s_magic: u16, // Should be EXT4_SUPER_MAGIC (0xEF53)

    /// Returns the block size from s_log_block_size
    pub fn blockSize(self: *const Ext4Superblock) u32 {
        return EXT4_MIN_BLOCK_SIZE << self.s_log_block_size;
    }

    /// Validates that this is a valid ext4 superblock
    pub fn validate(self: *const Ext4Superblock) ImageError!void {
        if (self.s_magic != EXT4_SUPER_MAGIC) {
            return ImageError.InvalidMagicNumber;
        }

        const block_size = self.blockSize();
        if (block_size < EXT4_MIN_BLOCK_SIZE) {
            return ImageError.InvalidBlockSize;
        }
    }
};

pub const Image = struct {
    file: fs.File,
    superblock: Ext4Superblock,
    allocator: Allocator,
    block_size: u32,

    pub fn open(allocator: Allocator, file: fs.File) !*Image {
        var superblock = try superblockFromFile(file);
        try superblock.validate();

        const image = try allocator.create(Image);
        image.* = Image{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
            .block_size = superblock.blockSize(),
        };

        return image;
    }

    pub fn close(self: *Image) void {
        self.file.close();
        self.allocator.destroy(self);
    }

    fn superblockFromFile(file: fs.File) !Ext4Superblock {
        try file.seekTo(SUPERBLOCK_OFFSET);

        // Read the superblock
        var superblock: Ext4Superblock = undefined;
        const read_bytes = try file.read(mem.asBytes(&superblock));

        if (read_bytes < @sizeOf(Ext4Superblock)) {
            return ImageError.ReadError;
        }

        return superblock;
    }

    pub fn readBlock(self: *const Image, block_index: u64, buffer: []u8) !void {
        if (buffer.len < self.block_size) {
            return ImageError.OutOfBounds;
        }

        const offset = block_index * self.block_size;
        try self.file.seekTo(offset);

        const bytes_read = try self.file.read(buffer[0..self.block_size]);
        if (bytes_read != self.block_size) {
            return ImageError.ReadError;
        }
    }
};
