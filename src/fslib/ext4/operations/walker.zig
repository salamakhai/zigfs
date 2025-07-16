//! Functions for navigating directories and finding entries

const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("../error.zig").Ext4Error;
const Entry = @import("../types/entry.zig").Entry;
const Superblock = @import("../types/superblock.zig").Superblock;
const DiskReader = @import("../disk/reader.zig").Reader;
const entries_parsing = @import("../parsing/entries.zig");
const reader = @import("reader.zig");

// Public
pub fn readDirectory(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    entry: *const Entry,
) ![]Entry {
    if (!entry.isDirectory()) {
        return Error.NotDirectory;
    }

    const inode_number = entry.inodeNumber();
    const inode = try disk_reader.readInodeByNumber(
        inode_number,
        superblock.inodesPerGroup(),
        256, // TODO: Get from superblock
    );

    if (!inode.isDirectory()) {
        return Error.NotDirectory;
    }

    const directory_data = try reader.readInodeData(allocator, disk_reader, superblock, &inode);
    defer allocator.free(directory_data);

    return entries_parsing.parseDirectoryEntries(directory_data, allocator);
}

pub fn findInDirectory(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    directory_entry: *const Entry,
    target_name: []const u8,
) !?Entry {
    const entries = try readDirectory(allocator, disk_reader, superblock, directory_entry);
    defer {
        for (entries) |*entry| {
            if (entry.name) |name| {
                allocator.free(name);
            }
        }
        allocator.free(entries);
    }

    for (entries) |entry| {
        if (entry.name) |name| {
            if (std.mem.eql(u8, name, target_name)) {
                return Entry{
                    .layout = entry.layout,
                    .name = try allocator.dupe(u8, name),
                };
            }
        }
    }

    return null;
}
