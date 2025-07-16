const BlockGroupLayout = @import("../disk/layout.zig").BlockGroupLayout;

pub const BlockGroup = struct {
    layout: BlockGroupLayout,

    pub fn inodeTableBlock(self: *const BlockGroup) u64 {
        return (@as(u64, self.layout.bg_inode_table_hi) << 32) | self.layout.bg_inode_table_lo;
    }

    pub fn blockBitmapBlock(self: *const BlockGroup) u64 {
        return (@as(u64, self.layout.bg_block_bitmap_hi) << 32) | self.layout.bg_block_bitmap_lo;
    }

    pub fn inodeBitmapBlock(self: *const BlockGroup) u64 {
        return (@as(u64, self.layout.bg_inode_bitmap_hi) << 32) | self.layout.bg_inode_bitmap_lo;
    }

    pub fn freeBlocks(self: *const BlockGroup) u32 {
        return (@as(u32, self.layout.bg_free_blocks_count_hi) << 16) | self.layout.bg_free_blocks_count_lo;
    }

    pub fn freeInodes(self: *const BlockGroup) u32 {
        return (@as(u32, self.layout.bg_free_inodes_count_hi) << 16) | self.layout.bg_free_inodes_count_lo;
    }

    pub fn usedDirs(self: *const BlockGroup) u32 {
        return (@as(u32, self.layout.bg_used_dirs_count_hi) << 16) | self.layout.bg_used_dirs_count_lo;
    }

    pub fn unusedInodes(self: *const BlockGroup) u32 {
        return (@as(u32, self.layout.bg_itable_unused_hi) << 16) | self.layout.bg_itable_unused_lo;
    }

    pub fn blockBitmapChecksum(self: *const BlockGroup) u32 {
        return (@as(u32, self.layout.bg_block_bitmap_csum_hi) << 16) | self.layout.bg_block_bitmap_csum_lo;
    }

    pub fn inodeBitmapChecksum(self: *const BlockGroup) u32 {
        return (@as(u32, self.layout.bg_inode_bitmap_csum_hi) << 16) | self.layout.bg_inode_bitmap_csum_lo;
    }

    pub fn excludeBitmap(self: *const BlockGroup) u64 {
        return (@as(u64, self.layout.bg_exclude_bitmap_hi) << 32) | self.layout.bg_exclude_bitmap_lo;
    }
};
