//! Parsing algorithms for EXT4 filesystem layouts

const std = @import("std");
const SuperblockLayout = @import("../layout/superblock_layout.zig").SuperblockLayout;
const BlockGroupLayout = @import("../layout/block_group_layout.zig").BlockGroupLayout;
const InodeLayout = @import("../layout/inode_layout.zig").InodeLayout;
const ExtentTreeLayout = @import("../layout/extent_layout.zig").ExtentTreeLayout;

const ExtentHeader = ExtentTreeLayout.ExtentHeader;
const Extent = ExtentTreeLayout.Extent;
const ExtentIndex = ExtentTreeLayout.ExtentIndex;

const Allocator = std.mem.Allocator;

// === Types ===
pub const ExtentMapping = struct {
    logical_start_block: u32,
    physical_start_block: u64,
    block_count: u16,
    is_uninitialized: bool,

    pub fn logicalByteOffset(self: ExtentMapping, block_size: u32) u64 {
        return @as(u64, self.logical_start_block) * block_size;
    }

    pub fn physicalByteOffset(self: ExtentMapping, block_size: u32) u64 {
        return self.physical_start_block * block_size;
    }

    pub fn sizeInBytes(self: ExtentMapping, block_size: u32) u64 {
        return @as(u64, self.block_count) * block_size;
    }

    pub fn containsLogicalBlock(self: ExtentMapping, logical_block: u32) bool {
        return logical_block >= self.logical_start_block and
            logical_block < self.logical_start_block + self.block_count;
    }
};

// === Superblock ===
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

// === Extent ===
pub fn parseExtentHeader(extent_data: []const u8) ?*const ExtentHeader {
    if (extent_data.len < @sizeOf(ExtentHeader)) {
        return null;
    }

    const header = @as(*const ExtentHeader, @ptrCast(@alignCast(extent_data.ptr)));

    if (header.eh_magic != ExtentHeader.MAGIC_NUMBER) {
        return null;
    }

    return header;
}

pub fn isExtentLeaf(header: *const ExtentHeader) bool {
    return header.eh_depth == 0;
}

/// Extent mappings from leaf node
pub fn extractExtentMappings(
    extent_data: []const u8,
    allocator: Allocator,
) ![]ExtentMapping {
    const header = parseExtentHeader(extent_data) orelse {
        return error.InvalidExtentHeader;
    };

    if (!isExtentLeaf(header)) {
        return error.NotALeafNode;
    }

    var mappings = try allocator.alloc(ExtentMapping, header.eh_entries);
    const extents_start = @sizeOf(ExtentHeader);

    for (0..header.eh_entries) |i| {
        const extent_offset = extents_start + i * @sizeOf(Extent);

        if (extent_offset + @sizeOf(Extent) > extent_data.len) {
            return error.ExtentDataTruncated;
        }

        const extent = @as(*const Extent, @ptrCast(@alignCast(&extent_data[extent_offset])));
        mappings[i] = parseExtentEntry(extent);
    }

    return mappings;
}

/// Extent indices from internal node
pub fn extractExtentIndices(
    extent_data: []const u8,
    allocator: Allocator,
) ![]ExtentIndex {
    const header = parseExtentHeader(extent_data) orelse {
        return error.InvalidExtentHeader;
    };

    if (isExtentLeaf(header)) {
        return error.NotAnInternalNode;
    }

    var indices = try allocator.alloc(ExtentIndex, header.eh_entries);

    const indices_start = @sizeOf(ExtentHeader);
    for (0..header.eh_entries) |i| {
        const index_offset = indices_start + i * @sizeOf(ExtentIndex);

        if (index_offset + @sizeOf(ExtentIndex) > extent_data.len) {
            return error.ExtentDataTruncated;
        }

        const index = @as(*const ExtentIndex, @ptrCast(@alignCast(&extent_data[index_offset])));
        indices[i] = index.*;
    }

    return indices;
}

fn parseExtentEntry(extent: *const Extent) ExtentMapping {
    const physical_start = (@as(u64, extent.ee_start_hi) << 32) | @as(u64, extent.ee_start_lo);
    const is_uninitialized = (extent.ee_len & ExtentTreeLayout.EXT4_EXTENT_FLAGS.UNWRITTEN) != 0;
    const actual_length = extent.ee_len & ~ExtentTreeLayout.EXT4_EXTENT_FLAGS.UNWRITTEN;

    return ExtentMapping{
        .logical_start_block = extent.ee_block,
        .physical_start_block = physical_start,
        .block_count = actual_length,
        .is_uninitialized = is_uninitialized,
    };
}

// === BlockGroup ===
pub fn parseBlockGroupDescriptor(bgd_data: []const u8) ?*const BlockGroupLayout {
    if (bgd_data.len < @sizeOf(BlockGroupLayout)) {
        return null;
    }

    return @as(*const BlockGroupLayout, @ptrCast(@alignCast(bgd_data.ptr)));
}

// === Inode ===
pub fn extractInodeBlockData(inode_layout: *const InodeLayout) []const u8 {
    return std.mem.asBytes(&inode_layout.i_block);
}
