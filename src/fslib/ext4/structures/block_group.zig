const std = @import("std");

pub const BlockGroupError = error{
    ReadError,
    InvalidBlockGroup,
    OutOfBounds,
};

pub const BlockGroup = extern struct {
    bg_block_bitmap_lo: u32, // Blocks bitmap block
    bg_inode_bitmap_lo: u32, // Inodes bitmap block
    bg_inode_table_lo: u32, // Inodes table block
    bg_free_blocks_count_lo: u16, // Free blocks count
    bg_free_inodes_count_lo: u16, // Free inodes count
    bg_used_dirs_count_lo: u16, // Directories count
    bg_flags: u16, // EXT4_BG_flags (INODE_UNINIT, etc)
    bg_exclude_bitmap_lo: u32, // Exclude bitmap for snapshots
    bg_block_bitmap_csum_lo: u16, // crc32c(s_uuid+grp_num+bbitmap) LE
    bg_inode_bitmap_csum_lo: u16, // crc32c(s_uuid+grp_num+ibitmap) LE
    bg_itable_unused_lo: u16, // Unused inodes count
    bg_checksum: u16, // crc16(sb_uuid+group+desc)

    pub fn inodeTableBlock(self: *const BlockGroup) u32 {
        return self.bg_inode_table_lo;
    }

    pub fn freeInodesCount(self: *const BlockGroup) u16 {
        return self.bg_free_inodes_count_lo;
    }
};
