const std = @import("std");

pub const EXT4_SUPER_MAGIC: u16 = 0xEF53;
pub const SUPERBLOCK_OFFSET: u64 = 1024;
pub const EXT4_MIN_BLOCK_SIZE: u32 = 1024;
pub const EXT4_MAX_BLOCK_SIZE: u32 = 65536; // 64KB
pub const EXT4_DEFAULT_BLOCK_SIZE: u32 = 4096;

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

pub const Superblock = packed struct {
    // Basic superblock fields (offset 0-59)
    s_inodes_count: u32, // 0x00-0x03
    s_blocks_count_lo: u32, // 0x04-0x07
    s_r_blocks_count_lo: u32, // 0x08-0x0B
    s_free_blocks_count_lo: u32, // 0x0C-0x0F
    s_free_inodes_count: u32, // 0x10-0x13
    s_first_data_block: u32, // 0x14-0x17
    s_log_block_size: u32, // 0x18-0x1B (using full u32 to maintain alignment)
    s_log_cluster_size: u32, // 0x1C-0x1F
    s_blocks_per_group: u32, // 0x20-0x23
    s_clusters_per_group: u32, // 0x24-0x27
    s_inodes_per_group: u32, // 0x28-0x2B
    s_mtime: u32, // 0x2C-0x2F
    s_wtime: u32, // 0x30-0x33
    s_mnt_count: u16, // 0x34-0x35
    s_max_mnt_count: i16, // 0x36-0x37
    s_magic: u16, // 0x38-0x39 (Should be EXT4_SUPER_MAGIC 0xEF53)

    pub fn fromFile(file: std.fs.File) anyerror!Superblock {
        try file.seekTo(SUPERBLOCK_OFFSET);

        var superblock: Superblock = undefined;
        const read_bytes = try file.read(std.mem.asBytes(&superblock));

        if (read_bytes < @sizeOf(Superblock)) {
            return SuperblockError.ReadError;
        }

        return superblock;
    }

    /// Returns the block size from s_log_block_size
    pub fn blockSize(self: *const Superblock) u32 {
        // Extract the lower 5 bits of s_log_block_size since we're using full u32 for alignment
        const log_block_size = @as(u5, @truncate(self.s_log_block_size));
        return EXT4_MIN_BLOCK_SIZE << log_block_size;
    }

    /// Validates that this is a valid ext4 superblock
    pub fn validate(self: *const Superblock, writer: anytype) (SuperblockError || @TypeOf(writer).Error)!void {
        try writer.print("Validating superblock...\n", .{});

        // Check magic number (handling potential endianness issues)
        try writer.print("Magic number: read=0x{X:0>4}, expected=0x{X:0>4}\n", .{ self.s_magic, EXT4_SUPER_MAGIC });
        if (self.s_magic != EXT4_SUPER_MAGIC) {
            // Try swapping bytes in case of endianness issues
            const swapped_magic = @byteSwap(self.s_magic);
            try writer.print("Swapped magic number: 0x{X:0>4}\n", .{swapped_magic});
            if (swapped_magic != EXT4_SUPER_MAGIC) {
                try writer.print("Magic number validation failed\n", .{});
                return SuperblockError.InvalidMagicNumber;
            }
        }

        // Check for required blocks
        try writer.print("Blocks count: {}\n", .{self.s_blocks_count_lo});
        if (self.s_blocks_count_lo == 0) {
            try writer.print("No blocks found\n", .{});
            return SuperblockError.NoBlocks;
        }

        // Check for required inodes
        try writer.print("Inodes count: {}\n", .{self.s_inodes_count});
        if (self.s_inodes_count == 0) {
            try writer.print("No inodes found\n", .{});
            return SuperblockError.NoInodes;
        }

        // Check for blocks per group
        try writer.print("Blocks per group: {}\n", .{self.s_blocks_per_group});
        if (self.s_blocks_per_group == 0) {
            try writer.print("Invalid blocks per group\n", .{});
            return SuperblockError.InvalidBlocksPerGroup;
        }

        // Check block size
        const block_size = self.blockSize();
        try writer.print("Block size: {} bytes (log_block_size={})\n", .{ block_size, self.s_log_block_size });

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
