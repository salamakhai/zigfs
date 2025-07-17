//! Entries reading operations

const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("../error.zig").Ext4Error;
const Inode = @import("../types/inode.zig").Inode;
const Entry = @import("../types/entry.zig").Entry;
const Superblock = @import("../types/superblock.zig").Superblock;
const DiskReader = @import("../disk/reader.zig").Reader;

const reader = @import("reader.zig");
const extents_parsing = @import("../parsing/extents.zig");

// Public
pub fn isReadable(
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    entry: *const Entry,
) bool {
    if (!entry.isFile()) {
        return false;
    }

    const file_inode = try readEntryInode(disk_reader, superblock, entry);
    return file_inode.isRegularFile();
}

pub fn getSize(
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    entry: *const Entry,
) !u64 {
    if (!entry.isFile()) {
        return Error.NotFile;
    }

    const file_inode = try readEntryInode(disk_reader, superblock, entry);

    if (!file_inode.isRegularFile()) {
        return Error.NotFile;
    }

    return file_inode.size();
}

pub fn readEntryInode(
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    entry: *const Entry,
) !Inode {
    const inode_number = entry.inodeNumber();
    const file_inode = try disk_reader.readInodeByNumber(
        inode_number,
        superblock.inodesPerGroup(),
        superblock.inodeSize(),
    );

    return file_inode;
}

pub fn readContent(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    entry: *const Entry,
) ![]u8 {
    if (!entry.isFile()) {
        return Error.NotFile;
    }

    const file_inode = try readEntryInode(disk_reader, superblock, entry);

    if (!file_inode.isRegularFile()) {
        return Error.NotFile;
    }

    return try reader.readInodeData(
        allocator,
        disk_reader,
        superblock,
        &file_inode,
    );
}

pub fn readContentPartial(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    entry: *const Entry,
    offset: u64,
    size: u64,
) ![]u8 {
    if (!entry.isFile()) {
        return Error.NotFile;
    }

    const full_data = try readContent(allocator, disk_reader, superblock, entry);
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

pub fn readInodeData(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    inode: *const Inode,
) ![]u8 {
    const data_size = inode.size();

    if (data_size == 0) {
        return try allocator.alloc(u8, 0);
    }

    const data = try allocator.alloc(u8, @intCast(data_size));
    try readFileContentWithExtents(disk_reader, superblock, data, inode);

    return data;
}

// Private
fn readFileContentWithExtents(
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    data: []u8,
    inode: *const Inode,
) !void {
    const block_data = inode.blockData();
    const extent_data = std.mem.asBytes(&block_data);

    const header = extents_parsing.parseExtentHeader(extent_data) orelse {
        return Error.ReadError;
    };

    if (extents_parsing.isExtentLeaf(header)) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const temp_allocator = arena.allocator();

        const mappings = extents_parsing.parseExtentMappings(
            extent_data,
            temp_allocator,
        ) catch {
            return Error.ReadError;
        };

        for (mappings) |mapping| {
            try readExtentMapping(disk_reader, superblock, data, mapping);
        }
    } else {
        return Error.ReadError;
    }
}

fn readExtentMapping(
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    data: []u8,
    mapping: extents_parsing.ExtentMapping,
) !void {
    const logical_offset = mapping.logicalByteOffset(superblock.blockSize());
    const physical_offset = mapping.physicalByteOffset(superblock.blockSize());
    const extent_size = mapping.sizeInBytes(superblock.blockSize());

    const bytes_to_read = @min(extent_size, data.len - logical_offset);

    if (logical_offset + bytes_to_read > data.len) {
        return Error.ReadError;
    }

    const read_bytes = try disk_reader.readAt(
        physical_offset,
        data[logical_offset .. logical_offset + bytes_to_read],
    );

    if (read_bytes != bytes_to_read) {
        return Error.ReadError;
    }
}
