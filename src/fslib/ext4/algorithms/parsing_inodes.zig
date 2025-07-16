//! Inode parsing algorithms for EXT4 filesystem

const std = @import("std");
const InodeLayout = @import("../layout/inode_layout.zig").InodeLayout;

// === Public ===
pub fn extractInodeBlockData(inode_layout: *const InodeLayout) []const u8 {
    return std.mem.asBytes(&inode_layout.i_block);
}
