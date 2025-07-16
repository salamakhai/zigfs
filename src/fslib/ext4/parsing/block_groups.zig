const std = @import("std");
const BlockGroupLayout = @import("../disk/layout.zig").BlockGroupLayout;
const SuperblockLayout = @import("../disk/layout.zig").SuperblockLayout;

// Parsers
pub fn parseBlockGroupDescriptor(bgd_data: []const u8) ?*const BlockGroupLayout {
    if (bgd_data.len < @sizeOf(BlockGroupLayout)) {
        return null;
    }

    return @as(*const BlockGroupLayout, @ptrCast(@alignCast(bgd_data.ptr)));
}

// Validators
pub fn validateBlockGroupNumber(block_group: u32, total_block_groups: u32) bool {
    return block_group < total_block_groups;
}

pub fn validateDescriptor(bgd: *const BlockGroupLayout, superblock_layout: *const SuperblockLayout) bool {
    _ = bgd;
    _ = superblock_layout;

    return true;
}

pub fn validateDescriptorBounds(bgd_data: []const u8) bool {
    return bgd_data.len >= @sizeOf(BlockGroupLayout);
}

pub fn validateFreeSpaceCounts(bgd: *const BlockGroupLayout, superblock_layout: *const SuperblockLayout) bool {
    if (bgd.bg_free_blocks_count > superblock_layout.s_blocks_per_group) return false;
    if (bgd.bg_free_inodes_count > superblock_layout.s_inodes_per_group) return false;

    return true;
}

pub fn validateMetadataBlocks(bgd: *const BlockGroupLayout, block_group: u32, superblock_layout: *const SuperblockLayout) bool {
    const blocks_per_group = superblock_layout.s_blocks_per_group;
    const group_start_block = @as(u64, block_group) * blocks_per_group;
    const group_end_block = group_start_block + blocks_per_group;

    if (bgd.bg_block_bitmap < group_start_block or bgd.bg_block_bitmap >= group_end_block) return false;
    if (bgd.bg_inode_bitmap < group_start_block or bgd.bg_inode_bitmap >= group_end_block) return false;
    if (bgd.bg_inode_table < group_start_block or bgd.bg_inode_table >= group_end_block) return false;

    return true;
}
