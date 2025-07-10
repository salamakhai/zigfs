const BlockGroupLayout = @import("../layout/block_group_layout.zig").BlockGroupLayout;

pub const BlockGroup = struct {
    // Variables
    layout: BlockGroupLayout,

    // Public
    pub fn inodeTableBlock(self: *const BlockGroup) u32 {
        return self.layout.bg_inode_table_lo;
    }

    pub fn blockBitmapBlock(self: *const BlockGroup) u32 {
        return self.layout.bg_block_bitmap_lo;
    }

    pub fn inodeBitmapBlock(self: *const BlockGroup) u32 {
        return self.layout.bg_inode_bitmap_lo;
    }

    pub fn freeBlocks(self: *const BlockGroup) u16 {
        return self.layout.bg_free_blocks_count_lo;
    }

    pub fn freeInodes(self: *const BlockGroup) u16 {
        return self.layout.bg_free_inodes_count_lo;
    }

    pub fn usedDirs(self: *const BlockGroup) u16 {
        return self.layout.bg_used_dirs_count_lo;
    }
};
