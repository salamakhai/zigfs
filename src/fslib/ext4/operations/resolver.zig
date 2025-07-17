//! Path resolution operations

const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("../error.zig").Ext4Error;
const Entry = @import("../types/entry.zig").Entry;
const Superblock = @import("../types/superblock.zig").Superblock;
const DiskReader = @import("../disk/reader.zig").Reader;
const walker = @import("walker.zig");

// Public
pub fn getRootEntry(
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
) !Entry {
    const root_inode = try disk_reader.readInodeByNumber(
        2,
        superblock.inodesPerGroup(),
        superblock.inodeSize(),
    );

    if (!root_inode.isDirectory()) {
        return Error.NotDirectory;
    }

    return Entry.create(2, 1, Entry.FileType.DIR, "/");
}

pub fn resolvePath(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    path: []const u8,
) !Entry {
    if (path.len == 0) {
        return Error.EntryNotFound;
    }

    if (std.mem.eql(u8, path, "/")) {
        return getRootEntry(disk_reader, superblock);
    }

    var current_entry = try getRootEntry(disk_reader, superblock);

    var path_components = std.ArrayList([]const u8).init(allocator);
    defer path_components.deinit();

    try splitPath(path, &path_components);

    for (path_components.items) |component| {
        if (component.len == 0) continue;

        const next_entry = try findEntryInDirectory(
            allocator,
            disk_reader,
            superblock,
            &current_entry,
            component,
        );

        if (current_entry.name) |name| {
            if (!std.mem.eql(u8, name, "/")) {
                allocator.free(name);
            }
        }
        current_entry = next_entry;
    }

    return current_entry;
}

// Private
fn findEntryInDirectory(
    allocator: Allocator,
    disk_reader: *const DiskReader,
    superblock: *const Superblock,
    directory_entry: *const Entry,
    target_name: []const u8,
) !Entry {
    if (!directory_entry.isDirectory()) {
        return Error.NotDirectory;
    }

    if (try walker.findInDirectory(
        allocator,
        disk_reader,
        superblock,
        directory_entry,
        target_name,
    )) |target_entry| {
        return target_entry;
    }

    return Error.EntryNotFound;
}

fn splitPath(path: []const u8, components: *std.ArrayList([]const u8)) !void {
    var start: usize = 0;

    if (path.len > 0 and path[0] == '/') {
        start = 1;
    }

    var i = start;
    while (i <= path.len) {
        if (i == path.len or path[i] == '/') {
            if (i > start) {
                try components.append(path[start..i]);
            }
            start = i + 1;
        }
        i += 1;
    }
}
