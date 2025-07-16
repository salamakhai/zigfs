//! Algorithms for calculating inode physical locations in EXT4 filesystem
//! They convert logical inode numbers to physical disk locations through:
//! 1. Block group calculation (which group contains the inode)
//! 2. Block group descriptor location (where to find group metadata)
//! 3. Inode table location (where inodes are stored within the group)
//! 4. Individual inode offset (specific inode within the table)
//!
//! References:
//! - https://docs.kernel.org/filesystems/ext4/dynamic.html#finding-an-inode
//! - EXT4 inode numbering starts at 1 (not 0)
//!
const std = @import("std");
const Superblock = @import("../structures/superblock.zig").Superblock;
const BlockGroupLayout = @import("../layout/block_group_layout.zig").BlockGroupLayout;

pub const InodeLocation = struct {
    /// Block group containing this inode
    block_group_number: u32,
    /// Index within the block group's inode table
    inode_index_in_group: u32,
    /// Physical offset of block group descriptor on disk
    block_group_descriptor_offset: u64,
    /// Physical offset of the inode on disk
    inode_offset: u64,
    /// Size of each inode structure
    inode_size: u32,
};

/// Calculate complete physical location of an inode
pub fn calculateLocation(
    inode_number: u32,
    superblock: *const Superblock,
) InodeLocation {
    std.debug.assert(inode_number > 0); // EXT4 inode numbers start at 1

    const block_size = superblock.blockSize();

    // Step 1: Determine which block group contains this inode
    const block_group_number = calculateBlockGroupNumber(inode_number, superblock);
    const inode_index_in_group = calculateInodeIndexInGroup(inode_number, superblock);

    // Step 2: Calculate block group descriptor location
    const bgd_offset = calculateBlockGroupDescriptorOffset(block_group_number, block_size);

    // Step 3: Calculate inode size (depends on filesystem revision)
    const inode_size = calculateInodeSize(superblock);

    return InodeLocation{
        .block_group_number = block_group_number,
        .inode_index_in_group = inode_index_in_group,
        .block_group_descriptor_offset = bgd_offset,
        .inode_offset = 0, // Will be calculated after reading BGD
        .inode_size = inode_size,
    };
}

/// Calculate which block group contains a given inode
pub fn calculateBlockGroupNumber(
    inode_number: u32,
    superblock: *const Superblock,
) u32 {
    // Inode numbers start at 1, so subtract 1 for zero-based calculation
    return (inode_number - 1) / superblock.layout.s_inodes_per_group;
}

/// Calculate inode index within its block group's inode table
pub fn calculateInodeIndexInGroup(
    inode_number: u32,
    superblock: *const Superblock,
) u32 {
    // Inode numbers start at 1, so subtract 1 for zero-based indexing
    return (inode_number - 1) % superblock.layout.s_inodes_per_group;
}

/// Calculate physical offset of block group descriptor on disk
///
/// Block group descriptors are stored in a table that immediately follows
/// the superblock. For 1KB block filesystems, the BGD table is at block 2
pub fn calculateBlockGroupDescriptorOffset(
    block_group_number: u32,
    block_size: u32,
) u64 {
    const bgd_table_block: u64 = if (block_size == 1024) 2 else 1;

    const bgd_size = @sizeOf(BlockGroupLayout);

    return (bgd_table_block * block_size) + (block_group_number * bgd_size);
}

/// Calculate the physical offset of an inode within the inode table
pub fn calculateInodeOffset(
    inode_table_start_block: u64,
    inode_index_in_group: u32,
    inode_size: u32,
    block_size: u32,
) u64 {
    const inode_table_start_offset = inode_table_start_block * block_size;
    const inode_offset_in_table = @as(u64, inode_index_in_group) * inode_size;

    return inode_table_start_offset + inode_offset_in_table;
}

/// Determine inode structure size based on filesystem revision
///
/// Original EXT4 used 128-byte inodes. Extended revision uses 256 bytes
/// to accommodate additional timestamps and extended attributes
pub fn calculateInodeSize(superblock: *const Superblock) u32 {
    // Use explicit inode size if available in newer superblock versions
    if (superblock.layout.s_rev_level >= 1) {
        // Could use superblock.s_inode_size if we had full superblock layout
        return 256; // Extended inode size for revision 1+
    } else {
        return 128; // Original inode size
    }
}
