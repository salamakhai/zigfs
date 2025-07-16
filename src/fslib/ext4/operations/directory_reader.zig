const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;

const parsing = @import("../algorithms/parsing.zig");

pub const DirectoryReader = struct {
    reader: *const Reader,

    pub fn init(reader: *const Reader) DirectoryReader {
        return DirectoryReader{
            .reader = reader,
        };
    }

    pub fn readDirectory(
        self: *const DirectoryReader,
        allocator: Allocator,
        entry: *const Entry,
    ) ![]Entry {
        if (!entry.isDirectory()) {
            return Error.NotDirectory;
        }

        const inode_number = entry.inodeNumber();
        const inode = try self.reader.readInode(inode_number);

        if (!inode.isDirectory()) {
            return Error.NotDirectory;
        }

        const directory_data = try self.reader.readInodeData(&inode);
        defer allocator.free(directory_data);

        const parsed_entries = try parsing.parseDirectoryEntries(directory_data, allocator);
        defer {
            for (parsed_entries) |parsed_entry| {
                allocator.free(parsed_entry.name);
            }
            allocator.free(parsed_entries);
        }

        var entries = try allocator.alloc(Entry, parsed_entries.len);
        for (parsed_entries, 0..) |parsed_entry, i| {
            entries[i] = Entry{
                .layout = parsed_entry.layout,
                .name = try allocator.dupe(u8, parsed_entry.name),
            };
        }

        return entries;
    }

    pub fn findInDirectory(
        self: *const DirectoryReader,
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
