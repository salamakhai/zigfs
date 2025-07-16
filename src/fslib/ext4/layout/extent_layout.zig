const std = @import("std");

/// EXT4 Extent Tree Layout
/// 
/// This represents the raw on-disk structures for EXT4's extent-based block allocation
/// Extent trees provide efficient mapping from logical file blocks to physical disk blocks
/// 
/// References
/// - Docs: https://docs.kernel.org/filesystems/ext4/dynamic.html#extent-tree
/// - Kernel: https://github.com/torvalds/linux/blob/master/fs/ext4/ext4_extents.h
///
/// Extent Tree Structure:
/// - Root is stored in inode's i_block array (when EXT4_EXTENTS_FL is set)
/// - Internal nodes contain ExtentIndex entries pointing to child nodes
/// - Leaf nodes contain Extent entries mapping logical to physical blocks
/// - Tree depth is stored in ExtentHeader.eh_depth (0 = leaf, >0 = internal)
pub const ExtentTreeLayout = struct {
    
    /// Extent Header - found at the beginning of all extent blocks
    /// Present in both leaf and internal nodes
    pub const ExtentHeader = extern struct {
        eh_magic: u16,      // 0x00: Magic number (0xF30A)
        eh_entries: u16,    // 0x02: Number of valid entries following this header
        eh_max: u16,        // 0x04: Maximum number of entries that can follow
        eh_depth: u16,      // 0x06: Tree depth (0 = leaf node, >0 = internal node)
        eh_generation: u32, // 0x08: Generation number for consistency checking
        
        pub const MAGIC_NUMBER: u16 = 0xF30A;
        
        comptime {
            std.debug.assert(@sizeOf(ExtentHeader) == 12);
        }
    };
    
    /// Extent Entry - used in leaf nodes
    /// Maps a range of logical blocks to a contiguous range of physical blocks
    pub const Extent = extern struct {
        ee_block: u32,      // 0x00: First logical block number covered by extent
        ee_len: u16,        // 0x04: Number of blocks covered by extent (max 32768)
        ee_start_hi: u16,   // 0x06: Upper 16 bits of physical block start address
        ee_start_lo: u32,   // 0x08: Lower 32 bits of physical block start address
        
        /// Maximum extent length
        pub const MAX_LEN: u16 = 32768;
        
        comptime {
            std.debug.assert(@sizeOf(Extent) == 12);
        }
    };
    
    /// Extent Index Entry (used in internal nodes)
    /// Points to child extent tree nodes (either internal nodes or leaf nodes)
    pub const ExtentIndex = extern struct {
        ei_block: u32,      // 0x00: First logical block number covered by subtree
        ei_leaf_lo: u32,    // 0x04: Lower 32 bits of physical block of child node
        ei_leaf_hi: u16,    // 0x08: Upper 16 bits of physical block of child node
        ei_unused: u16,     // 0x0A: Reserved field (must be zero)
        
        comptime {
            std.debug.assert(@sizeOf(ExtentIndex) == 12);
        }
    };
    
    // Important extent flags (stored in high bit of ee_len)
    pub const EXT4_EXTENT_FLAGS = struct {
        /// Extent is uninitialized (allocated but not written)
        pub const UNWRITTEN: u16 = 0x8000;
    };
    
    // Constants for extent tree structure
    pub const EXTENT_CONSTANTS = struct {
        /// Extent tree magic number
        pub const EXT4_EXTENTS_FL: u32 = 0x00080000;
        
        /// Maximum entries that can fit in inode's i_block area
        /// i_block is 60 bytes, header is 12 bytes, leaving 48 bytes
        /// Each entry is 12 bytes, so max 4 entries in inode
        pub const INODE_MAX_ENTRIES: u16 = 4;
        
        /// Calculate max entries for a given block size
        pub fn maxEntriesForBlockSize(block_size: u32) u16 {
            return @intCast((block_size - @sizeOf(ExtentHeader)) / @sizeOf(Extent));
        }
    };
};
