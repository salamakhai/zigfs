const InodeLayout = @import("../layout/inode_layout.zig").InodeLayout;

pub const Inode = struct {
    layout: InodeLayout,

    pub fn isDirectory(self: *const Inode) bool {
        return (self.layout.i_mode & 0xF000) == 0x4000;
    }

    pub fn isRegularFile(self: *const Inode) bool {
        return (self.layout.i_mode & 0xF000) == 0x8000;
    }

    pub fn isSymlink(self: *const Inode) bool {
        return (self.layout.i_mode & 0xF000) == 0xA000;
    }

    pub fn size(self: *const Inode) u64 {
        return @as(u64, self.layout.i_size_lo) | (@as(u64, self.layout.i_size_high) << 32);
    }
};