const std = @import("std");

// Ext4 extent constants
pub const EXT4_EXTENTS_FL: u32 = 0x80000;
pub const EXT4_HEADER_MAGIC: u16 = 0xF30A;

/// Extent header - found at the beginning of extent blocks
pub const ExtentHeader = extern struct {
    eh_magic: u16, // Magic number
    eh_entries: u16, // Number of valid entries
    eh_max: u16, // Maximum number of entries
    eh_depth: u16, // Depth of the tree (0 for leaf nodes)
    eh_generation: u32, // Generation number

    pub fn isValid(self: *const ExtentHeader) bool {
        return self.eh_magic == EXT4_HEADER_MAGIC;
    }

    pub fn isLeaf(self: *const ExtentHeader) bool {
        return self.eh_depth == 0;
    }
};

/// Extent entry for leaf nodes
pub const Extent = extern struct {
    ee_block: u32, // First logical block number
    ee_len: u16, // Number of blocks covered by extent
    ee_start_hi: u16, // Upper 16 bits of physical block number
    ee_start_lo: u32, // Lower 32 bits of physical block number

    pub fn startBlock(self: *const Extent) u64 {
        return (@as(u64, self.ee_start_hi) << 32) | @as(u64, self.ee_start_lo);
    }

    pub fn length(self: *const Extent) u16 {
        return self.ee_len;
    }

    pub fn logicalBlock(self: *const Extent) u32 {
        return self.ee_block;
    }
};

/// Extent index for internal nodes
pub const ExtentIndex = extern struct {
    ei_block: u32, // First logical block number covered by this index
    ei_leaf_lo: u32, // Lower 32 bits of physical block number of child
    ei_leaf_hi: u16, // Upper 16 bits of physical block number of child
    ei_unused: u16, // Unused field

    pub fn leafBlock(self: *const ExtentIndex) u64 {
        return (@as(u64, self.ei_leaf_hi) << 32) | @as(u64, self.ei_leaf_lo);
    }
};
