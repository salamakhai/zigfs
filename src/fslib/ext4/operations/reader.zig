const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("../error.zig").Ext4Error;

const Entry = @import("../types/entry.zig").Entry;
const Inode = @import("../types/inode.zig").Inode;
const Superblock = @import("../types/superblock.zig").Superblock;

const DiskReader = @import("../disk/reader.zig").Reader;
const extent_parsing = @import("../parsing/extents.zig");

pub const Reader = struct {
    // Fields
    reader: *const DiskReader,
    superblock: *const Superblock,

    // Lifecycle
    pub fn init(reader: *const DiskReader, superblock: *const Superblock) Reader {
        return Reader{
            .reader = reader,
            .superblock = superblock,
        };
    }

    // Public
    pub fn isReadable(self: *const Reader, entry: *const Entry) !bool {
        if (!entry.isFile()) {
            return false;
        }

        const inode_number = entry.inodeNumber();
        const file_inode = self.reader.readInodeByNumber(
            inode_number,
            self.superblock.inodesPerGroup(),
            256, // TODO: Get from superblock
        ) catch {
            return false;
        };

        return file_inode.isRegularFile();
    }

    pub fn getSize(self: *const Reader, entry: *const Entry) !u64 {
        if (!entry.isFile()) {
            return Error.NotFile;
        }

        const inode_number = entry.inodeNumber();
        const file_inode = try self.reader.readInodeByNumber(
            inode_number,
            self.superblock.inodesPerGroup(),
            256, // TODO: Get from superblock
        );

        if (!file_inode.isRegularFile()) {
            return Error.NotFile;
        }

        return file_inode.size();
    }

    pub fn readContent(self: *const Reader, entry: *const Entry) ![]u8 {
        if (!entry.isFile()) {
            return Error.NotFile;
        }

        const inode_number = entry.inodeNumber();
        const file_inode = try self.reader.readInodeByNumber(
            inode_number,
            self.superblock.inodesPerGroup(),
            256, // TODO: Get from superblock
        );

        if (!file_inode.isRegularFile()) {
            return Error.NotFile;
        }

        return try self.readInodeData(&file_inode);
    }

    pub fn readContentPartial(
        self: *const Reader,
        allocator: Allocator,
        entry: *const Entry,
        offset: u64,
        size: u64,
    ) ![]u8 {
        if (!entry.isFile()) {
            return Error.NotFile;
        }

        const full_data = try self.readContent(entry);
        defer allocator.free(full_data);

        if (offset >= full_data.len) {
            return try allocator.alloc(u8, 0);
        }

        const start = offset;
        const end = @min(offset + size, full_data.len);
        const partial_size = end - start;

        const partial_data = try allocator.alloc(u8, partial_size);
        @memcpy(partial_data, full_data[start..end]);

        return partial_data;
    }

    fn readInodeData(self: *const Reader, inode: *const Inode) ![]u8 {
        const data_size = inode.size();

        if (data_size == 0) {
            return try self.reader.allocator.alloc(u8, 0);
        }

        const data = try self.reader.allocator.alloc(u8, @intCast(data_size));
        try self.readFileContentWithExtents(data, inode);

        return data;
    }

    fn readFileContentWithExtents(self: *const Reader, data: []u8, inode: *const Inode) !void {
        const block_data = inode.blockData();
        const extent_data = std.mem.asBytes(&block_data);

        const header = extent_parsing.parseExtentHeader(extent_data) orelse {
            return Error.ReadError;
        };

        if (extent_parsing.isExtentLeaf(header)) {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            const mappings = extent_parsing.parseExtentMappings(
                extent_data,
                allocator,
            ) catch {
                return Error.ReadError;
            };

            for (mappings) |mapping| {
                try self.readExtentMapping(data, mapping);
            }
        } else {
            return Error.ReadError;
        }
    }

    fn readExtentMapping(self: *const Reader, data: []u8, mapping: extent_parsing.ExtentMapping) !void {
        const logical_offset = mapping.logicalByteOffset(self.superblock.blockSize());
        const physical_offset = mapping.physicalByteOffset(self.superblock.blockSize());
        const extent_size = mapping.sizeInBytes(self.superblock.blockSize());

        const bytes_to_read = @min(extent_size, data.len - logical_offset);

        if (logical_offset + bytes_to_read > data.len) {
            return Error.ReadError;
        }

        const read_bytes = try self.reader.readAt(
            physical_offset,
            data[logical_offset .. logical_offset + bytes_to_read],
        );

        if (read_bytes != bytes_to_read) {
            return Error.ReadError;
        }
    }
};
