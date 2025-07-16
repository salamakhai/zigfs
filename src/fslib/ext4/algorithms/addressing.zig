//! Address calculation algorithms for EXT4 filesystem
//! Converters from logical positions to physical disk addresses

const std = @import("std");
const SuperblockLayout = @import("../layout/superblock_layout.zig").SuperblockLayout;
const BlockGroupLayout = @import("../layout/block_group_layout.zig").BlockGroupLayout;

// === Public ===
pub fn blockToOffset(block_number: u64, block_size: u32) u64 {
    return block_number * block_size;
}

pub fn offsetToBlock(offset: u64, block_size: u32) u64 {
    return offset / block_size;
}

pub fn inodeToBlockGroup(inode_number: u32, inodes_per_group: u32) u32 {
    std.debug.assert(inode_number > 0);
    return (inode_number - 1) / inodes_per_group;
}

pub fn inodeToGroupIndex(inode_number: u32, inodes_per_group: u32) u32 {
    std.debug.assert(inode_number > 0);
    return (inode_number - 1) % inodes_per_group;
}

/// Calculate offset for item in a table
pub fn tableItemOffset(
    table_block: u64,
    item_index: u32,
    item_size: u32,
    block_size: u32,
) u64 {
    const table_offset = blockToOffset(table_block, block_size);
    const item_offset = @as(u64, item_index) * item_size;
    return table_offset + item_offset;
}

/// Calculate offset for descriptor in descriptor table
pub fn descriptorTableOffset(
    descriptor_index: u32,
    descriptor_size: u32,
    block_size: u32,
) u64 {
    const descriptor_table_block: u64 = if (block_size == 1024) 2 else 1;
    const byte_offset = blockToOffset(descriptor_table_block, block_size);
    return byte_offset + (descriptor_index * descriptor_size);
}

/// Calculate block group descriptor offset
pub fn blockGroupDescriptorOffset(block_group: u32, block_size: u32) u64 {
    return descriptorTableOffset(
        block_group,
        @sizeOf(BlockGroupLayout),
        block_size,
    );
}

/// Calculate inode table offset
pub fn inodeTableOffset(
    inode_table_block: u64,
    inode_index: u32,
    inode_size: u32,
    block_size: u32,
) u64 {
    return tableItemOffset(
        inode_table_block,
        inode_index,
        inode_size,
        block_size,
    );
}
