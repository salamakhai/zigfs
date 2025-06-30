const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Superblock = @import("../structures/superblock.zig").Superblock;
const Inode = @import("../structures/inode.zig").Inode;
const BlockGroup = @import("../structures/block_group.zig").Ext4BlockGroup;
const ExtentHeader = @import("../structures/extent.zig").ExtentHeader;
const Extent = @import("../structures/extent.zig").Extent;
const errors = @import("../../errors.zig");

const InodeLocationAlgorithm = @import("../algorithms/inode_location.zig").InodeLocationAlgorithm;
const ExtentResolutionAlgorithm = @import("../algorithms/extent_resolution.zig").ExtentResolutionAlgorithm;

pub const Reader = struct {
    file: fs.File,
    superblock: *const Superblock,
    block_size: u32,

    pub fn init(file: fs.File, superblock: *const Superblock) Reader {
        return Reader{
            .file = file,
            .superblock = superblock,
            .block_size = superblock.blockSize(),
        };
    }

    pub fn readInode(self: *const Reader, inode_number: u32) !Inode {
        if (inode_number == 0) {
            return errors.FileSystemError.ReadError;
        }

        const location = InodeLocationAlgorithm.calculateLocation(
            inode_number,
            &self.superblock.layout,
            self.block_size,
        );

        const bgd = try self.readBlockGroupDescriptor(location.block_group_number);

        const inode_offset = InodeLocationAlgorithm.calculateInodeOffset(
            bgd.inodeTableBlock(),
            location.inode_index_in_group,
            location.inode_size,
            self.block_size,
        );

        // Read inode at calculated location
        return self.readInodeAt(inode_offset);
    }

    pub fn readFileData(self: *const Reader, allocator: Allocator, inode: *const Inode) ![]u8 {
        const file_size = inode.size();

        if (file_size == 0) {
            return try allocator.alloc(u8, 0);
        }

        const data = try allocator.alloc(u8, @intCast(file_size));
        try self.readFileContentUsingExtents(data, inode);

        return data;
    }

    fn readFileContentUsingExtents(self: *const Reader, data: []u8, inode: *const Inode) !void {
        const extent_data = std.mem.asBytes(&inode.i_block);

        const header = ExtentResolutionAlgorithm.parseExtentHeader(extent_data) orelse {
            return errors.FileSystemError.ReadError;
        };

        if (ExtentResolutionAlgorithm.isLeafNode(header)) {
            // Use algorithm to extract extent mappings
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const allocator = arena.allocator();
            
            const mappings = ExtentResolutionAlgorithm.extractLeafExtents(extent_data, allocator) catch {
                return errors.FileSystemError.ReadError;
            };

            // Read each extent mapping
            for (mappings) |mapping| {
                try self.readExtentMapping(data, mapping);
            }
        } else {
            // TODO: Handle internal extent tree nodes
            return errors.FileSystemError.ReadError;
        }
    }

    /// Read block group descriptor at specific location
    fn readBlockGroupDescriptor(self: *const Reader, group_number: u32) !BlockGroup {
        const bgd_offset = InodeLocationAlgorithm.calculateBlockGroupDescriptorOffset(
            group_number,
            self.block_size,
        );
        
        try self.file.seekTo(bgd_offset);
        
        var bgd: BlockGroup = undefined;
        const read_bytes = try self.file.read(std.mem.asBytes(&bgd));
        if (read_bytes < @sizeOf(BlockGroup)) {
            return errors.FileSystemError.ReadError;
        }
        
        return bgd;
    }

    /// Read inode at specific physical offset
    fn readInodeAt(self: *const Reader, offset: u64) !Inode {
        try self.file.seekTo(offset);
        
        var inode: Inode = undefined;
        const read_bytes = try self.file.read(std.mem.asBytes(&inode));
        if (read_bytes < @sizeOf(Inode)) {
            return errors.FileSystemError.ReadError;
        }
        
        return inode;
    }

    /// Read data for a single extent mapping
    fn readExtentMapping(self: *const Reader, data: []u8, mapping: ExtentResolutionAlgorithm.ExtentMapping) !void {
        const logical_offset = mapping.logicalByteOffset(self.block_size);
        const physical_offset = mapping.physicalByteOffset(self.block_size);
        const extent_size = mapping.sizeInBytes(self.block_size);
        
        const bytes_to_read = @min(extent_size, data.len - logical_offset);
        if (logical_offset + bytes_to_read > data.len) {
            return errors.FileSystemError.ReadError;
        }

        try self.file.seekTo(physical_offset);
        const read_bytes = try self.file.read(data[logical_offset .. logical_offset + bytes_to_read]);

        if (read_bytes != bytes_to_read) {
            return errors.FileSystemError.ReadError;
        }
    }
};