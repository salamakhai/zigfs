//! Block group parsing algorithms for EXT4 filesystem

const std = @import("std");
const BlockGroupLayout = @import("../layout/block_group_layout.zig").BlockGroupLayout;

// === Public ===
pub fn parseBlockGroupDescriptor(bgd_data: []const u8) ?*const BlockGroupLayout {
    if (bgd_data.len < @sizeOf(BlockGroupLayout)) {
        return null;
    }

    return @as(*const BlockGroupLayout, @ptrCast(@alignCast(bgd_data.ptr)));
}
