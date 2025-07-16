const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("../error.zig").Ext4Error;

const Entry = @import("../types/entry.zig").Entry;
const Inode = @import("../types/inode.zig").Inode;
const Superblock = @import("../types/superblock.zig").Superblock;
const Reader = @import("../disk/reader.zig").Reader;

const parsing = @import("../parsing/entries.zig");

pub const Walker = struct {
    // Fields
    reader: *const Reader,
    superblock: *const Superblock,

    // Lifecycle
    pub fn init(reader: *const Reader, superblock: *const Superblock) Walker {
        return Walker{
            .reader = reader,
            .superblock = superblock,
        };
    }

    // Public
    pub fn readDirectory(
        self: *const Walker,
        allocator: Allocator,
        entry: *const Entry,
    ) ![]Entry {
        if (!entry.isDirectory()) {
            return Error.NotDirectory;
        }

        const inode_number = entry.inodeNumber();
        const inode = try self.reader.readInodeByNumber(
            inode_number,
            self.superblock.inodesPerGroup(),
            256, // TODO: Get from superblock
        );

        if (!inode.isDirectory()) {
            return Error.NotDirectory;
        }

        // TODO: Read via extents
        const directory_data = try self.reader.readAlloc(0, inode.size());
        defer allocator.free(directory_data);

        return parsing.parseDirectoryEntries(directory_data, allocator);
    }

    pub fn findInDirectory(
        self: *const Walker,
        allocator: Allocator,
        directory_entry: *const Entry,
        target_name: []const u8,
    ) !?Entry {
        const entries = try self.readDirectory(allocator, directory_entry);
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
};
