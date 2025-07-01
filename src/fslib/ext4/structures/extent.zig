const std = @import("std");

const extent_layout = @import("../layout/extent_layout.zig");

const ExtentTreeLayout = extent_layout.ExtentTreeLayout;
const ExtentHeaderLayout = ExtentTreeLayout.ExtentHeader;
const ExtentLayout = ExtentTreeLayout.Extent;
const ExtentIndexLayout = ExtentTreeLayout.ExtentIndex;

const EXTENT_CONSTANTS = ExtentTreeLayout.EXTENT_CONSTANTS;

pub const ExtentHeader = extern struct {
    layout: ExtentHeaderLayout,

    pub fn isValid(self: *const ExtentHeader) bool {
        return self.layout.eh_magic == ExtentHeaderLayout.EXT4_HEADER_MAGIC;
    }

    pub fn isLeaf(self: *const ExtentHeader) bool {
        return self.layout.eh_depth == 0;
    }
};

pub const Extent = extern struct {
    layout: ExtentLayout,

    pub fn startBlock(self: *const Extent) u64 {
        return (@as(u64, self.layout.ee_start_hi) << 32) | @as(u64, self.layout.ee_start_lo);
    }

    pub fn length(self: *const Extent) u16 {
        return self.layout.ee_len;
    }

    pub fn logicalBlock(self: *const Extent) u32 {
        return self.layout.ee_block;
    }
};

pub const ExtentIndex = extern struct {
    layout: ExtentIndexLayout,

    pub fn leafBlock(self: *const ExtentIndex) u64 {
        return (@as(u64, self.layout.ei_leaf_hi) << 32) | @as(u64, self.layout.ei_leaf_lo);
    }
};
