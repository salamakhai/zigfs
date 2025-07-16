//! Superblock parsing algorithms for EXT4 filesystem

const std = @import("std");
const SuperblockLayout = @import("../layout/superblock_layout.zig").SuperblockLayout;

// === Public ===
pub fn blockSize(superblock_layout: *const SuperblockLayout) u32 {
    const log_block_size = @as(u5, @truncate(superblock_layout.s_log_block_size));
    return SuperblockLayout.MIN_BLOCK_SIZE << log_block_size;
}

pub fn inodeSize(superblock_layout: *const SuperblockLayout) u32 {
    return if (superblock_layout.s_rev_level >= 1) 256 else 128;
}

pub fn totalBlockGroups(superblock_layout: *const SuperblockLayout) u32 {
    return (superblock_layout.s_blocks_count_lo + superblock_layout.s_blocks_per_group - 1) / superblock_layout.s_blocks_per_group;
}
