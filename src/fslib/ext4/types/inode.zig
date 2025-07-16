const std = @import("std");
const InodeLayout = @import("../disk/layout.zig").InodeLayout;

pub const Inode = struct {
    layout: InodeLayout,

    pub fn fromLayout(layout: InodeLayout) Inode {
        return Inode{ .layout = layout };
    }

    pub fn blockData(self: *const Inode) [60]u8 {
        return std.mem.asBytes(&self.layout.i_block).*;
    }

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

    pub fn size(self: *const Inode) u64 {
        return @as(u64, self.layout.i_size_lo) | (@as(u64, self.layout.i_size_high) << 32);
    }

    pub fn sizeInBlocks(self: *const Inode, block_size: u32) u64 {
        const file_size = self.size();
        return (file_size + block_size - 1) / block_size;
    }

    pub fn mode(self: *const Inode) u16 {
        return self.layout.i_mode;
    }

    pub fn permissions(self: *const Inode) u16 {
        return self.layout.i_mode & InodeLayout.PERM_MASK;
    }

    pub fn formatPermissions(self: *const Inode, buffer: []u8) ![]const u8 {
        if (buffer.len < 10) return error.BufferTooSmall;

        const file_mode = self.layout.i_mode;

        buffer[0] = switch (file_mode & InodeLayout.FILE_TYPE_MASK) {
            InodeLayout.FILE_TYPE_DIR => 'd',
            InodeLayout.FILE_TYPE_REGULAR => '-',
            InodeLayout.FILE_TYPE_SYMLINK => 'l',
            InodeLayout.FILE_TYPE_BLOCKDEV => 'b',
            InodeLayout.FILE_TYPE_CHARDEV => 'c',
            InodeLayout.FILE_TYPE_FIFO => 'p',
            InodeLayout.FILE_TYPE_SOCKET => 's',
            else => '?',
        };

        buffer[1] = if (file_mode & InodeLayout.S_IRUSR != 0) 'r' else '-';
        buffer[2] = if (file_mode & InodeLayout.S_IWUSR != 0) 'w' else '-';
        buffer[3] = if (file_mode & InodeLayout.S_IXUSR != 0)
            (if (file_mode & InodeLayout.S_ISUID != 0) 's' else 'x')
        else
            (if (file_mode & InodeLayout.S_ISUID != 0) 'S' else '-');

        buffer[4] = if (file_mode & InodeLayout.S_IRGRP != 0) 'r' else '-';
        buffer[5] = if (file_mode & InodeLayout.S_IWGRP != 0) 'w' else '-';
        buffer[6] = if (file_mode & InodeLayout.S_IXGRP != 0)
            (if (file_mode & InodeLayout.S_ISGID != 0) 's' else 'x')
        else
            (if (file_mode & InodeLayout.S_ISGID != 0) 'S' else '-');

        buffer[7] = if (file_mode & InodeLayout.S_IROTH != 0) 'r' else '-';
        buffer[8] = if (file_mode & InodeLayout.S_IWOTH != 0) 'w' else '-';
        buffer[9] = if (file_mode & InodeLayout.S_IXOTH != 0)
            (if (file_mode & InodeLayout.S_ISVTX != 0) 't' else 'x')
        else
            (if (file_mode & InodeLayout.S_ISVTX != 0) 'T' else '-');

        return buffer[0..10];
    }

    pub fn hasPermission(self: *const Inode, permission: u16) bool {
        return (self.layout.i_mode & permission) != 0;
    }
};
