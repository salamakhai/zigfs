const std = @import("std");
const extent_layout = @import("../layout/extent_layout.zig");

const ExtentTreeLayout = extent_layout.ExtentTreeLayout;
const ExtentHeader = ExtentTreeLayout.ExtentHeader;
const Extent = ExtentTreeLayout.Extent;
const ExtentIndex = ExtentTreeLayout.ExtentIndex;

/// Algorithms for resolving EXT4 extent trees to block mappings
/// 
/// These algorithms implement extent tree traversal and logical-to-physical
/// block mapping without IO operations. They parse extent tree structures
/// and calculate physical disk locations for file data.
///
/// EXT4 Extent Tree Structure:
/// - Root stored in inode's i_block array (60 bytes)
/// - Internal nodes contain ExtentIndex entries pointing to child nodes
/// - Leaf nodes contain Extent entries mapping logical -> physical blocks
/// - Tree depth in ExtentHeader.eh_depth (0=leaf, >0=internal)
///
/// References:
/// - https://docs.kernel.org/filesystems/ext4/dynamic.html#extent-tree
pub const ExtentResolutionAlgorithm = struct {
    
    /// Single extent mapping from logical to physical blocks
    pub const ExtentMapping = struct {
        /// First logical block covered by this extent
        logical_start_block: u32,
        /// First physical block of this extent  
        physical_start_block: u64,
        /// Number of blocks in this extent
        block_count: u16,
        /// Whether this extent is uninitialized (allocated but not written)
        is_uninitialized: bool,
        
        /// Calculate logical byte offset for this extent
        pub fn logicalByteOffset(self: ExtentMapping, block_size: u32) u64 {
            return @as(u64, self.logical_start_block) * block_size;
        }
        
        /// Calculate physical byte offset for this extent  
        pub fn physicalByteOffset(self: ExtentMapping, block_size: u32) u64 {
            return self.physical_start_block * block_size;
        }
        
        /// Calculate total size of this extent in bytes
        pub fn sizeInBytes(self: ExtentMapping, block_size: u32) u64 {
            return @as(u64, self.block_count) * block_size;
        }
        
        /// Check if a logical block is within this extent
        pub fn containsLogicalBlock(self: ExtentMapping, logical_block: u32) bool {
            return logical_block >= self.logical_start_block and 
                   logical_block < self.logical_start_block + self.block_count;
        }
    };
    
    /// Parse extent tree header from raw bytes
    pub fn parseExtentHeader(extent_data: []const u8) ?*const ExtentHeader {
        if (extent_data.len < @sizeOf(ExtentHeader)) {
            return null;
        }
        
        const header = @as(*const ExtentHeader, @ptrCast(@alignCast(extent_data.ptr)));
        
        if (header.eh_magic != ExtentHeader.MAGIC_NUMBER) {
            return null;
        }
        
        return header;
    }
    
    /// Extract all extent mappings from a leaf node
    /// 
    /// Leaf nodes contain actual extent entries that map logical blocks
    /// to physical blocks. This function parses all extents in the node.
    pub fn extractLeafExtents(
        extent_data: []const u8,
        allocator: std.mem.Allocator,
    ) ![]ExtentMapping {
        const header = parseExtentHeader(extent_data) orelse {
            return error.InvalidExtentHeader;
        };
        
        if (!isLeafNode(header)) {
            return error.NotALeafNode;
        }
        
        var mappings = try allocator.alloc(ExtentMapping, header.eh_entries);
        
        const extents_start = @sizeOf(ExtentHeader);
        for (0..header.eh_entries) |i| {
            const extent_offset = extents_start + i * @sizeOf(Extent);
            
            if (extent_offset + @sizeOf(Extent) > extent_data.len) {
                return error.ExtentDataTruncated;
            }
            
            const extent = @as(*const Extent, @ptrCast(@alignCast(&extent_data[extent_offset])));
            mappings[i] = parseExtentEntry(extent);
        }
        
        return mappings;
    }
    
    /// Parse a single extent entry into mapping information
    fn parseExtentEntry(extent: *const Extent) ExtentMapping {
        // Combine high and low parts for 48-bit physical block address
        const physical_start = (@as(u64, extent.ee_start_hi) << 32) | @as(u64, extent.ee_start_lo);
        
        // Check uninitialized flag (high bit of length)
        const is_uninitialized = (extent.ee_len & ExtentTreeLayout.EXT4_EXTENT_FLAGS.UNWRITTEN) != 0;
        const actual_length = extent.ee_len & ~ExtentTreeLayout.EXT4_EXTENT_FLAGS.UNWRITTEN;
        
        return ExtentMapping{
            .logical_start_block = extent.ee_block,
            .physical_start_block = physical_start,
            .block_count = actual_length,
            .is_uninitialized = is_uninitialized,
        };
    }
    
    /// Extract extent indices from an internal node
    /// 
    /// Internal nodes contain indices pointing to child extent tree nodes.
    /// Each index covers a range of logical blocks and points to a physical block
    /// containing the child node.
    pub fn extractInternalIndices(
        extent_data: []const u8,
        allocator: std.mem.Allocator,
    ) ![]ExtentIndex {
        const header = parseExtentHeader(extent_data) orelse {
            return error.InvalidExtentHeader;
        };
        
        if (isLeafNode(header)) {
            return error.NotAnInternalNode;
        }
        
        var indices = try allocator.alloc(ExtentIndex, header.eh_entries);
        
        const indices_start = @sizeOf(ExtentHeader);
        for (0..header.eh_entries) |i| {
            const index_offset = indices_start + i * @sizeOf(ExtentIndex);
            
            if (index_offset + @sizeOf(ExtentIndex) > extent_data.len) {
                return error.ExtentDataTruncated;
            }
            
            const index = @as(*const ExtentIndex, @ptrCast(@alignCast(&extent_data[index_offset])));
            indices[i] = index.*;
        }
        
        return indices;
    }
    
    /// Find the extent mapping that contains a specific logical block
    /// 
    /// Searches through extent mappings to find which one covers
    /// the requested logical block number.
    pub fn findExtentForLogicalBlock(
        mappings: []const ExtentMapping,
        logical_block: u32,
    ) ?ExtentMapping {
        for (mappings) |mapping| {
            if (mapping.containsLogicalBlock(logical_block)) {
                return mapping;
            }
        }
        return null;
    }
    
    /// Calculate read operations needed to copy extent data
    /// 
    /// Determines the physical disk reads required to copy data from
    /// an extent into a target buffer, handling partial block reads.
    pub fn calculateReadOperations(
        mapping: ExtentMapping,
        target_logical_offset: u64,
        target_size: u64,
        block_size: u32,
    ) []const ReadOperation {
        // This will calculate the specific disk reads needed
        _ = mapping;
        _ = target_logical_offset;
        _ = target_size;
        _ = block_size;
        
        // TODO: Implement read operation calculation
        return &[_]ReadOperation{};
    }

    /// Single disk read operation
    pub const ReadOperation = struct {
        physical_offset: u64,
        target_buffer_offset: usize,
        size: usize,
    };
    
    // Helpers
    pub fn isLeafNode(header: *const ExtentHeader) bool {
        return header.eh_depth == 0;
    }
    
    pub fn isValidExtentHeader(header: *const ExtentHeader) bool {
        return header.eh_magic == ExtentHeader.MAGIC_NUMBER;
    }
};