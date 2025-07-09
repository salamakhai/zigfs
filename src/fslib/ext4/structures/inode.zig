const std = @import("std");
const InodeLayout = @import("../layout/inode_layout.zig").InodeLayout;

/// High-level wrapper for EXT4 inode layout
/// 
/// Provides convenient methods for working with inodes
/// without exposing the underlying layout details.
pub const Inode = struct {
    layout: InodeLayout,

    /// Create Inode from layout
    pub fn fromLayout(layout: InodeLayout) Inode {
        return Inode{ .layout = layout };
    }

    pub fn blockData(self: *const Inode) [60]u8 {
        return std.mem.asBytes(&self.layout.i_block).*;
    }

    // === Types ===
    pub fn isDirectory(self: *const Inode) bool {
        return (self.layout.i_mode & InodeLayout.FILE_TYPE_MASK) == InodeLayout.FILE_TYPE_DIR;
    }

    pub fn isRegularFile(self: *const Inode) bool {
        return (self.layout.i_mode & InodeLayout.FILE_TYPE_MASK) == InodeLayout.FILE_TYPE_REGULAR;
    }

    pub fn isSymlink(self: *const Inode) bool {
        return (self.layout.i_mode & InodeLayout.FILE_TYPE_MASK) == InodeLayout.FILE_TYPE_SYMLINK;
    }

    pub fn isCharacterDevice(self: *const Inode) bool {
        return (self.layout.i_mode & InodeLayout.FILE_TYPE_MASK) == InodeLayout.FILE_TYPE_CHARDEV;
    }

    pub fn isBlockDevice(self: *const Inode) bool {
        return (self.layout.i_mode & InodeLayout.FILE_TYPE_MASK) == InodeLayout.FILE_TYPE_BLOCKDEV;
    }

    pub fn isFifo(self: *const Inode) bool {
        return (self.layout.i_mode & InodeLayout.FILE_TYPE_MASK) == InodeLayout.FILE_TYPE_FIFO;
    }

    pub fn isSocket(self: *const Inode) bool {
        return (self.layout.i_mode & InodeLayout.FILE_TYPE_MASK) == InodeLayout.FILE_TYPE_SOCKET;
    }

    pub fn isDevice(self: *const Inode) bool {
        return self.isCharacterDevice() or self.isBlockDevice();
    }

    // === Size Information ===
    pub fn size(self: *const Inode) u64 {
        return @as(u64, self.layout.i_size_lo) | (@as(u64, self.layout.i_size_high) << 32);
    }

    /// Get size in filesystem blocks
    pub fn sizeInBlocks(self: *const Inode, block_size: u32) u64 {
        const file_size = self.size();
        return (file_size + block_size - 1) / block_size;
    }

    // === Permissions ===
    /// Get raw mode value
    pub fn mode(self: *const Inode) u16 {
        return self.layout.i_mode;
    }

    /// Get file permissions (without type bits)
    pub fn permissions(self: *const Inode) u16 {
        return self.layout.i_mode & InodeLayout.PERM_MASK;
    }

    /// Check specific permission
    pub fn hasPermission(self: *const Inode, permission: u16) bool {
        return (self.layout.i_mode & permission) != 0;
    }

    // === Validation ===
    pub fn isValid(self: *const Inode) bool {
        // Basic validation
        if (self.layout.i_mode == 0) return false;
        if (self.layout.i_links_count == 0 and !self.isDirectory()) return false;

        const file_type = self.fileType();
        return file_type != .unknown;
    }

    // === Debug ===
    pub fn format(
        self: *const Inode,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Inode{{ type={}, mode=0o{o}, size={}, links={} }}", .{
            self.fileType(),
            self.layout.i_mode,
            self.size(),
            self.layout.i_links_count,
        });
    }
};