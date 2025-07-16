//! Extent validation algorithms for EXT4 filesystem

const std = @import("std");
const ExtentTreeLayout = @import("../layout/extent_layout.zig").ExtentTreeLayout;

const ExtentHeader = ExtentTreeLayout.ExtentHeader;
const Extent = ExtentTreeLayout.Extent;
const ExtentIndex = ExtentTreeLayout.ExtentIndex;

// === Public ===
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
    // Check for reasonable block count (not zero, not too large)
    const actual_length = extent.ee_len & ~ExtentTreeLayout.EXT4_EXTENT_FLAGS.UNWRITTEN;

    if (actual_length == 0) return false;
    // EXT4 limit for initialized extents
    if (actual_length > 32768) return false;
    // Check for invalid logical block
    if (extent.ee_block == 0xFFFFFFFF) return false;

    return true;
}

pub fn validateExtentIndex(index: *const ExtentIndex) bool {
    // Check for invalid logical block
    if (index.ei_block == 0xFFFFFFFF) return false;

    // Check that physical block is not zero
    const physical_block = (@as(u64, index.ei_leaf_hi) << 32) | @as(u64, index.ei_leaf_lo);
    if (physical_block == 0) return false;

    return true;
}

pub fn validateExtentDataBounds(extent_data: []const u8, header: *const ExtentHeader) bool {
    const required_size = @sizeOf(ExtentHeader);
    if (extent_data.len < required_size) return false;

    if (header.eh_depth == 0) {
        // Leaf node - check extent entries
        const entries_size = header.eh_entries * @sizeOf(Extent);
        return extent_data.len >= required_size + entries_size;
    } else {
        // Internal node - check extent indices
        const indices_size = header.eh_entries * @sizeOf(ExtentIndex);
        return extent_data.len >= required_size + indices_size;
    }
}

pub fn validateExtentTreeStructure(extent_data: []const u8) bool {
    if (extent_data.len < @sizeOf(ExtentHeader)) return false;

    const header = @as(*const ExtentHeader, @ptrCast(@alignCast(extent_data.ptr)));

    if (!validateHeader(header)) return false;
    if (!validateExtentDataBounds(extent_data, header)) return false;

    return true;
}
