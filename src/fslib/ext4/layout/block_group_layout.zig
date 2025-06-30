const std = @import("std");

/// EXT4 Block Group Descriptor Layout
/// 
/// Represents the raw on-disk structure of an EXT4 block group descriptor
/// Block group descriptors track metadata for each block group in the filesystem
/// 
/// References
/// - Docs: https://docs.kernel.org/filesystems/ext4/globals.html#block-group-descriptors
/// - Kernel: https://github.com/torvalds/linux/blob/master/fs/ext4/ext4.h
///
/// The block group descriptor contains:
/// - Locations of allocation bitmaps and inode table
/// - Free space and inode counters
/// - Checksums for verifications
/// - Flags indicating block group state
pub const BlockGroupLayout = extern struct {
    // Bitmap and table locations (0x00-0x0B)
    bg_block_bitmap_lo: u32,    // 0x00: Block bitmap block (lower 32 bits)
    bg_inode_bitmap_lo: u32,    // 0x04: Inode bitmap block (lower 32 bits)
    bg_inode_table_lo: u32,     // 0x08: Inode table first block (lower 32 bits)
    
    // Allocation counters (0x0C-0x13)
    bg_free_blocks_count_lo: u16, // 0x0C: Free blocks count (lower 16 bits)
    bg_free_inodes_count_lo: u16, // 0x0E: Free inodes count (lower 16 bits)
    bg_used_dirs_count_lo: u16,   // 0x10: Directory count (lower 16 bits)
    bg_flags: u16,                // 0x12: Block group flags
    
    // Extended features and checksums (0x14-0x1F)
    bg_exclude_bitmap_lo: u32,    // 0x14: Snapshot exclude bitmap (lower 32 bits)
    bg_block_bitmap_csum_lo: u16, // 0x18: Block bitmap checksum (lower 16 bits)
    bg_inode_bitmap_csum_lo: u16, // 0x1A: Inode bitmap checksum (lower 16 bits)
    bg_itable_unused_lo: u16,     // 0x1C: Unused inode count (lower 16 bits)
    bg_checksum: u16,             // 0x1E: Group descriptor checksum
    
    // Block group flags
    pub const BG_FLAGS = struct {
        /// Inode table and bitmap are not initialized
        pub const INODE_UNINIT: u16 = 0x0001;
        /// Block bitmap is not initialized
        pub const BLOCK_UNINIT: u16 = 0x0002;
        /// Inode table is zeroed
        pub const INODE_ZEROED: u16 = 0x0004;
    };
    
    comptime {
        // Compile time check:
        // Ensure the block group descriptor layout is 32 bytes
        // This is the size for the basic descriptor
        std.debug.assert(@sizeOf(BlockGroupLayout) == 32);
    }
    
    // Note: EXT4 supports extended block group descriptors (64 bytes) when
    // the EXT4_FEATURE_INCOMPAT_64BIT flag is set. The extended version
    // includes high 32-bit fields for all the _lo fields above.
    // For this basic filesystem support, the 32-byte version is sufficient.
};