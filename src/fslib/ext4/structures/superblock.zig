const std = @import("std");
const errors = @import("../../errors.zig");
const SuperblockLayout = @import("../layout/superblock_layout.zig").SuperblockLayout;
const SuperblockValidationAlgorithm = @import("../algorithms/superblock_validation.zig").SuperblockValidationAlgorithm;

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

        return Superblock{
            .layout = layout,
        };
    }

    pub fn blockSize(self: *const Superblock) u32 {
        const validation_result = SuperblockValidationAlgorithm.validateBlockSize(&self.layout);
        return validation_result.block_size;
    }

    pub fn validate(
        self: *const Superblock,
        writer: anytype,
    ) (SuperblockError || @TypeOf(writer).Error)!void {
        try writer.print("Validating superblock...\n", .{});

        const validation_result = SuperblockValidationAlgorithm.validateSuperblock(&self.layout);

        try writer.print("Magic number: read=0x{X:0>4}, expected=0x{X:0>4}\n", .{ self.layout.s_magic, EXT4_SUPER_MAGIC });
        try writer.print("Blocks count: {}\n", .{self.layout.s_blocks_count_lo});
        try writer.print("Inodes count: {}\n", .{self.layout.s_inodes_count});
        try writer.print("Blocks per group: {}\n", .{self.layout.s_blocks_per_group});
        try writer.print("Block size: {} bytes (log_block_size={})\n", .{ validation_result.detected_block_size, self.layout.s_log_block_size });

        if (!validation_result.is_valid) {
            try writer.print("Validation failed: {s}\n", .{validation_result.error_details});

            // Map to error types
            if (!validation_result.magic_number_valid) {
                return SuperblockError.InvalidMagicNumber;
            } else if (!validation_result.block_size_valid) {
                return SuperblockError.InvalidBlockSize;
            } else if (!validation_result.counts_valid) {
                return SuperblockError.NoBlocks;
            } else if (!validation_result.layout_valid) {
                return SuperblockError.InvalidBlocksPerGroup;
            }
        }

        try writer.print("All validation checks passed\n", .{});
    }
};
