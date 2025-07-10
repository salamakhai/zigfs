const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const FilesystemError = @import("../ext4_error.zig").Ext4Error;

const Superblock = @import("../structures/superblock.zig").Superblock;
const Inode = @import("../structures/inode.zig").Inode;
const BlockGroup = @import("../structures/block_group.zig").BlockGroup;
const ExtentHeader = @import("../structures/extent.zig").ExtentHeader;
const Extent = @import("../structures/extent.zig").Extent;

const InodeLocationAlgorithm = @import("../algorithms/inode_location.zig").InodeLocationAlgorithm;
const ExtentResolutionAlgorithm = @import("../algorithms/extent_resolution.zig").ExtentResolutionAlgorithm;

/// Low-level block and inode reading
pub const Reader = struct {
    // === Variables ===
    allocator: Allocator,
    file: fs.File,
    superblock: *const Superblock,
    block_size: u32,

    // Lifecycle
    pub fn init(
        allocator: Allocator,
        file: fs.File,
        superblock: *const Superblock,
    ) Reader {
        return Reader{
            .allocator = allocator,
            .file = file,
            .superblock = superblock,
            .block_size = superblock.blockSize(),
        };
    }

    // Public
    pub fn readInode(self: *const Reader, inode_number: u32) !Inode {
        if (inode_number == 0) {
            return FilesystemError.ReadError;
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

        return self.readInodeAt(inode_offset);
    }

    pub fn readInodeData(self: *const Reader, inode: *const Inode) ![]u8 {
        const data_size = inode.size();

        if (data_size == 0) {
            return try self.allocator.alloc(u8, 0);
        }

        const data = try self.allocator.alloc(u8, @intCast(data_size));
        try self.readFileContentWithExtents(data, inode);

        return data;
    }

    // Private
    fn readFileContentWithExtents(self: *const Reader, data: []u8, inode: *const Inode) !void {
        const block_data = inode.blockData();
        const extent_data = std.mem.asBytes(&block_data);

        const header = ExtentResolutionAlgorithm.parseExtentHeader(extent_data) orelse {
            return FilesystemError.ReadError;
        };

        if (ExtentResolutionAlgorithm.isLeafNode(header)) {
            // Use algorithm to extract extent mappings

            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            const mappings = ExtentResolutionAlgorithm.extractLeafExtents(extent_data, allocator) catch {
                return FilesystemError.ReadError;
            };

            // Read each extent mapping
            for (mappings) |mapping| {
                try self.readExtentMapping(data, mapping);
            }
        } else {
            // TODO: Handle internal extent tree nodes
            return FilesystemError.ReadError;
        }
    }

    fn readBlockGroupDescriptor(self: *const Reader, group_number: u32) !BlockGroup {
        const bgd_offset = InodeLocationAlgorithm.calculateBlockGroupDescriptorOffset(
            group_number,
            self.block_size,
        );

        try self.file.seekTo(bgd_offset);

        var bgd: BlockGroup = undefined;
        const read_bytes = try self.file.read(std.mem.asBytes(&bgd));
        if (read_bytes < @sizeOf(BlockGroup)) {
            return FilesystemError.ReadError;
        }

        return bgd;
    }

    fn readInodeAt(self: *const Reader, offset: u64) !Inode {
        try self.file.seekTo(offset);

        var inode: Inode = undefined;
        const read_bytes = try self.file.read(std.mem.asBytes(&inode));

        if (read_bytes < @sizeOf(Inode)) {
            return FilesystemError.ReadError;
        }

        return inode;
    }

    fn readExtentMapping(self: *const Reader, data: []u8, mapping: ExtentResolutionAlgorithm.ExtentMapping) !void {
        const logical_offset = mapping.logicalByteOffset(self.block_size);
        const physical_offset = mapping.physicalByteOffset(self.block_size);
        const extent_size = mapping.sizeInBytes(self.block_size);

        const bytes_to_read = @min(extent_size, data.len - logical_offset);

        if (logical_offset + bytes_to_read > data.len) {
            return FilesystemError.ReadError;
        }

        try self.file.seekTo(physical_offset);

        const read_bytes = try self.file.read(
            data[logical_offset .. logical_offset + bytes_to_read],
        );

        if (read_bytes != bytes_to_read) {
            return FilesystemError.ReadError;
        }
    }
};
