//! Functions for navigating directories and finding entries

const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("../error.zig").Ext4Error;
const Entry = @import("../types/entry.zig").Entry;
const Superblock = @import("../types/superblock.zig").Superblock;
const DiskReader = @import("../disk/reader.zig").Reader;
const entries_parsing = @import("../parsing/entries.zig");
const reader = @import("reader.zig");
const EntryContext = @import("../types/entry_context.zig").EntryContext;

// Public
pub fn readDirectoryContext(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    entry: *const Entry,
) !EntryContext {
    if (!entry.isDirectory()) {
        return Error.NotDirectory;
    }

    const inode_number = entry.inodeNumber();
    const inode = try disk_reader.readInodeByNumber(
        inode_number,
        superblock.inodesPerGroup(),
        superblock.inodeSize(),
    );

    if (!inode.isDirectory()) {
        return Error.NotDirectory;
    }

    const directory_data = try reader.readInodeData(
        allocator,
        disk_reader,
        superblock,
        &inode,
    );

    const entries = try entries_parsing.parseDirectoryEntries(
        directory_data,
        allocator,
    );

    return EntryContext.init(
        allocator,
        entries,
        directory_data,
    );
}

pub fn findInDirectory(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    directory_entry: *const Entry,
    target_name: []const u8,
) !?Entry {
    if (!directory_entry.isDirectory()) {
        return Error.NotDirectory;
    }

    const inode_number = directory_entry.inodeNumber();
    const inode = try disk_reader.readInodeByNumber(
        inode_number,
        superblock.inodesPerGroup(),
        superblock.inodeSize(),
    );

    if (!inode.isDirectory()) {
        return Error.NotDirectory;
    }

    var context = try readDirectoryContext(allocator, disk_reader, superblock, directory_entry);
    defer context.deinit();

    for (0..context.entries.len) |i| {
        if (context.entryNameEql(i, target_name)) {
            return context.entries[i];
        }
    }

    return null;
}
