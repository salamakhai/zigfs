const std = @import("std");
const errors = @import("../../errors.zig");
const SuperblockLayout = @import("../layout/superblock_layout.zig").SuperblockLayout;

// Temp reexports
pub const EXT4_SUPER_MAGIC: u16 = SuperblockLayout.MAGIC_NUMBER;
pub const SUPERBLOCK_OFFSET: u64 = SuperblockLayout.OFFSET_IN_DEVICE;
pub const EXT4_MIN_BLOCK_SIZE: u32 = SuperblockLayout.MIN_BLOCK_SIZE;
pub const EXT4_MAX_BLOCK_SIZE: u32 = SuperblockLayout.MAX_BLOCK_SIZE;
pub const EXT4_DEFAULT_BLOCK_SIZE: u32 = SuperblockLayout.DEFAULT_BLOCK_SIZE;

pub const SuperblockError = error{
    ReadError,
    InvalidMagicNumber,
    InvalidBlockSize,
    NoBlocks,
    NoInodes,
    InvalidBlocksPerGroup,
    BlockSizeNotPowerOf2,
    BlockSizeTooLarge,
};

pub const Superblock = struct {
    layout: SuperblockLayout,

    pub fn fromFile(file: std.fs.File) anyerror!Superblock {
        try file.seekTo(SUPERBLOCK_OFFSET);

        var layout: SuperblockLayout = undefined;
        const read_bytes = try file.read(std.mem.asBytes(&layout));

        if (read_bytes < @sizeOf(SuperblockLayout)) {
            return SuperblockError.ReadError;
        }

        return Superblock{ .layout = layout };
    }

    /// Returns the block size from s_log_block_size
    pub fn blockSize(self: *const Superblock) u32 {
        // Extract the lower 5 bits of s_log_block_size since we're using full u32 for alignment
        const log_block_size = @as(u5, @truncate(self.layout.s_log_block_size));
        return EXT4_MIN_BLOCK_SIZE << log_block_size;
    }

    /// Validates that this is a valid ext4 superblock
    pub fn validate(
        self: *const Superblock,
        writer: anytype,
    ) (SuperblockError || @TypeOf(writer).Error)!void {
        try writer.print("Validating superblock...\n", .{});

        // Check magic number (handling potential endianness issues)
        try writer.print("Magic number: read=0x{X:0>4}, expected=0x{X:0>4}\n", .{ self.layout.s_magic, EXT4_SUPER_MAGIC });
        if (self.layout.s_magic != EXT4_SUPER_MAGIC) {
            // Try swapping bytes in case of endianness issues
            const swapped_magic = @byteSwap(self.layout.s_magic);
            try writer.print("Swapped magic number: 0x{X:0>4}\n", .{swapped_magic});
            if (swapped_magic != EXT4_SUPER_MAGIC) {
                try writer.print("Magic number validation failed\n", .{});
                return SuperblockError.InvalidMagicNumber;
            }
        }

        // Check for required blocks
        try writer.print("Blocks count: {}\n", .{self.layout.s_blocks_count_lo});
        if (self.layout.s_blocks_count_lo == 0) {
            try writer.print("No blocks found\n", .{});
            return SuperblockError.NoBlocks;
        }

        // Check for required inodes
        try writer.print("Inodes count: {}\n", .{self.layout.s_inodes_count});
        if (self.layout.s_inodes_count == 0) {
            try writer.print("No inodes found\n", .{});
            return SuperblockError.NoInodes;
        }

        // Check for blocks per group
        try writer.print("Blocks per group: {}\n", .{self.layout.s_blocks_per_group});
        if (self.layout.s_blocks_per_group == 0) {
            try writer.print("Invalid blocks per group\n", .{});
            return SuperblockError.InvalidBlocksPerGroup;
        }

        // Check block size
        const block_size = self.blockSize();
        try writer.print("Block size: {} bytes (log_block_size={})\n", .{ block_size, self.layout.s_log_block_size });

        // Block size must be at least the minimum
        if (block_size < EXT4_MIN_BLOCK_SIZE) {
            try writer.print("Block size too small (minimum is {})\n", .{EXT4_MIN_BLOCK_SIZE});
            return SuperblockError.InvalidBlockSize;
        }

        // Block size must not exceed maximum
        if (block_size > EXT4_MAX_BLOCK_SIZE) {
            try writer.print("Block size too large (maximum is {})\n", .{EXT4_MAX_BLOCK_SIZE});
            return SuperblockError.BlockSizeTooLarge;
        }

        // Check if block size is a power of 2
        if ((block_size & (block_size - 1)) != 0) {
            try writer.print("Block size is not a power of 2\n", .{});
            return SuperblockError.BlockSizeNotPowerOf2;
        }

        try writer.print("All validation checks passed\n", .{});
    }
};
