const std = @import("std");
const Allocator = std.mem.Allocator;
const ExtentTreeLayout = @import("../disk/layout.zig").ExtentTreeLayout;

const ExtentHeader = ExtentTreeLayout.ExtentHeader;
const Extent = ExtentTreeLayout.Extent;
const ExtentIndex = ExtentTreeLayout.ExtentIndex;

// Types
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

// State
pub fn isExtentLeaf(header: *const ExtentHeader) bool {
    return header.eh_depth == 0;
}

// Parsers
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

pub fn parseExtentMappings(
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

pub fn parseExtentIndices(
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

// Validators
pub fn validateHeaderMagic(header: *const ExtentHeader) bool {
    return header.eh_magic == ExtentHeader.MAGIC_NUMBER;
}

pub fn validateHeader(header: *const ExtentHeader) bool {
    if (!validateHeaderMagic(header)) return false;
    if (header.eh_entries == 0) return false;
    if (header.eh_depth > 5) return false;

    return true;
}

pub fn validateExtentEntry(extent: *const Extent) bool {
    const actual_length = extent.ee_len & ~ExtentTreeLayout.EXT4_EXTENT_FLAGS.UNWRITTEN;

    if (actual_length == 0) return false;
    if (actual_length > 32768) return false;
    if (extent.ee_block == 0xFFFFFFFF) return false;

    return true;
}

pub fn validateExtentIndex(index: *const ExtentIndex) bool {
    if (index.ei_block == 0xFFFFFFFF) return false;

    const physical_block = (@as(u64, index.ei_leaf_hi) << 32) | @as(u64, index.ei_leaf_lo);
    if (physical_block == 0) return false;

    return true;
}
