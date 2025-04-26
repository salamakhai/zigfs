const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const EXT4_SUPER_MAGIC: u16 = 0xEF53;
pub const SUPERBLOCK_OFFSET: u64 = 1024;
pub const EXT4_MIN_BLOCK_SIZE: u32 = 1024;
pub const EXT4_MAX_BLOCK_SIZE: u32 = 65536; // 64KB
pub const EXT4_DEFAULT_BLOCK_SIZE: u32 = 4096;

pub const ImageError = error{
    InvalidMagicNumber,
    ReadError,
    NotExt4Format,
    InvalidBlockSize,
    OutOfBounds,
    NoBlocks,
    NoInodes,
    InvalidBlocksPerGroup,
    BlockSizeNotPowerOf2,
    BlockSizeTooLarge,
};

/// Structure representing ext4 superblock fields
pub const Ext4Superblock = packed struct {
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

    /// Returns the block size from s_log_block_size
    pub fn blockSize(self: *const Ext4Superblock) u32 {
        // Extract the lower 5 bits of s_log_block_size since we're using full u32 for alignment
        const log_block_size = @as(u5, @truncate(self.s_log_block_size));
        return EXT4_MIN_BLOCK_SIZE << log_block_size;
    }

    /// Validates that this is a valid ext4 superblock
    pub fn validate(self: *const Ext4Superblock) ImageError!void {
        print("DEBUG: Validating superblock...\n", .{});

        // Check magic number (handling potential endianness issues)
        print("DEBUG: Magic number: read=0x{X:0>4}, expected=0x{X:0>4}\n", .{ self.s_magic, EXT4_SUPER_MAGIC });
        if (self.s_magic != EXT4_SUPER_MAGIC) {
            // Try swapping bytes in case of endianness issues
            const swapped_magic = @byteSwap(self.s_magic);
            print("DEBUG: Swapped magic number: 0x{X:0>4}\n", .{swapped_magic});
            if (swapped_magic != EXT4_SUPER_MAGIC) {
                print("DEBUG: Magic number validation failed\n", .{});
                return ImageError.InvalidMagicNumber;
            }
        }

        // Check for required blocks
        print("DEBUG: Blocks count: {}\n", .{self.s_blocks_count_lo});
        if (self.s_blocks_count_lo == 0) {
            print("DEBUG: No blocks found\n", .{});
            return ImageError.NoBlocks;
        }

        // Check for required inodes
        print("DEBUG: Inodes count: {}\n", .{self.s_inodes_count});
        if (self.s_inodes_count == 0) {
            print("DEBUG: No inodes found\n", .{});
            return ImageError.NoInodes;
        }

        // Check for blocks per group
        print("DEBUG: Blocks per group: {}\n", .{self.s_blocks_per_group});
        if (self.s_blocks_per_group == 0) {
            print("DEBUG: Invalid blocks per group\n", .{});
            return ImageError.InvalidBlocksPerGroup;
        }

        // Check block size
        const block_size = self.blockSize();
        print("DEBUG: Block size: {} bytes (log_block_size={})\n", .{ block_size, self.s_log_block_size });

        // Block size must be at least the minimum
        if (block_size < EXT4_MIN_BLOCK_SIZE) {
            print("DEBUG: Block size too small (minimum is {})\n", .{EXT4_MIN_BLOCK_SIZE});
            return ImageError.InvalidBlockSize;
        }

        // Block size must not exceed maximum
        if (block_size > EXT4_MAX_BLOCK_SIZE) {
            print("DEBUG: Block size too large (maximum is {})\n", .{EXT4_MAX_BLOCK_SIZE});
            return ImageError.BlockSizeTooLarge;
        }

        // Check if block size is a power of 2
        if ((block_size & (block_size - 1)) != 0) {
            print("DEBUG: Block size is not a power of 2\n", .{});
            return ImageError.BlockSizeNotPowerOf2;
        }

        print("DEBUG: All validation checks passed\n", .{});
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
        print("DEBUG: Superblock struct size: {} bytes\n", .{@sizeOf(Ext4Superblock)});
        print("DEBUG: Reading superblock from offset: {}\n", .{SUPERBLOCK_OFFSET});

        try file.seekTo(SUPERBLOCK_OFFSET);

        // First read raw bytes for debugging
        var raw_buffer: [1024]u8 = undefined;
        const raw_bytes_read = try file.read(&raw_buffer);
        print("DEBUG: Read {} raw bytes\n", .{raw_bytes_read});

        // Print the first 64 bytes for inspection
        print("DEBUG: First 64 bytes of raw data:\n", .{});
        var i: usize = 0;
        while (i < 64 and i < raw_bytes_read) : (i += 1) {
            print("{x:0>2} ", .{raw_buffer[i]});
            if ((i + 1) % 16 == 0) {
                print("\n", .{});
            }
        }
        print("\n", .{});

        // Check for magic number in raw bytes (offset 56 in superblock struct)
        if (raw_bytes_read >= 58) {
            print("DEBUG: Bytes at offset 56-57: [0x{x:0>2}, 0x{x:0>2}]\n", .{ raw_buffer[56], raw_buffer[57] });

            // Correct little-endian byte order: first byte is least significant
            const magic_bytes_le = @as(u16, @intCast(raw_buffer[56])) | (@as(u16, @intCast(raw_buffer[57])) << 8);
            print("DEBUG: Magic bytes at expected offset (56-57) little-endian: 0x{X:0>4}\n", .{magic_bytes_le});

            // Alternative big-endian interpretation
            const magic_bytes_be = (@as(u16, @intCast(raw_buffer[56])) << 8) | @as(u16, @intCast(raw_buffer[57]));
            print("DEBUG: Magic bytes at expected offset (56-57) big-endian: 0x{X:0>4}\n", .{magic_bytes_be});
        }

        // Look for the magic number pattern (0xEF53) in the raw data
        i = 0;
        while (i + 1 < raw_bytes_read) : (i += 1) {
            // Use little-endian byte order: first byte is least significant
            const magic_bytes = @as(u16, @intCast(raw_buffer[i])) | (@as(u16, @intCast(raw_buffer[i + 1])) << 8);
            if (magic_bytes == EXT4_SUPER_MAGIC) {
                print("DEBUG: Found magic number 0xEF53 at offset: {}\n", .{i});
                print("DEBUG: Bytes: [0x{x:0>2}, 0x{x:0>2}]\n", .{ raw_buffer[i], raw_buffer[i + 1] });
            }
        }

        // Seek back to start position
        try file.seekTo(SUPERBLOCK_OFFSET);

        // Read the superblock
        var superblock: Ext4Superblock = undefined;
        const read_bytes = try file.read(mem.asBytes(&superblock));

        print("DEBUG: Read {} bytes into superblock struct\n", .{read_bytes});

        if (read_bytes < @sizeOf(Ext4Superblock)) {
            print("DEBUG: Not enough bytes read for superblock struct\n", .{});
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
