const std = @import("std");

pub const EXT4_NDIR_BLOCKS: u8 = 12;
pub const EXT4_IND_BLOCK: u8 = EXT4_NDIR_BLOCKS;
pub const EXT4_DIND_BLOCK: u8 = EXT4_IND_BLOCK + 1;
pub const EXT4_TIND_BLOCK: u8 = EXT4_DIND_BLOCK + 1;
pub const EXT4_N_BLOCKS: u8 = EXT4_TIND_BLOCK + 1;

pub const InodeError = error{
    ReadError,
    InvalidInodeNumber,
    OutOfBounds,
};

pub const Inode = extern struct {
    i_mode: u16, // File mode
    i_uid: u16, // Low 16 bits of Owner Uid
    i_size_lo: u32, // Size in bytes
    i_atime: u32, // Access time
    i_ctime: u32, // Inode Change time
    i_mtime: u32, // Modification time
    i_dtime: u32, // Deletion Time
    i_gid: u16, // Low 16 bits of Group Id
    i_links_count: u16, // Links count
    i_blocks_lo: u32, // Blocks count
    i_flags: u32, // File flags
    i_osd1: u32, // OS dependent 1
    i_block: [EXT4_N_BLOCKS]u32, // Pointers to blocks
    i_generation: u32, // File version (for NFS)
    i_file_acl_lo: u32, // File ACL
    i_size_high: u32, // File size high
    i_obso_faddr: u32, // Obsoleted fragment address
    i_osd2: [12]u8, // OS dependent 2

    pub fn isDirectory(self: *const Inode) bool {
        return (self.i_mode & 0xF000) == 0x4000;
    }

    pub fn isRegularFile(self: *const Inode) bool {
        return (self.i_mode & 0xF000) == 0x8000;
    }

    pub fn isSymlink(self: *const Inode) bool {
        return (self.i_mode & 0xF000) == 0xA000;
    }

    pub fn size(self: *const Inode) u64 {
        return @as(u64, self.i_size_lo) | (@as(u64, self.i_size_high) << 32);
    }
};
