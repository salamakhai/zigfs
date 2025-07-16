const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;

const DirectoryReader = @import("directory_reader.zig").DirectoryReader;

pub const PathResolver = struct {
    // Variables
    reader: *const Reader,
    directory_reader: DirectoryReader,

    // Lifecycle
    pub fn init(reader: *const Reader) PathResolver {
        return PathResolver{
            .reader = reader,
            .directory_reader = DirectoryReader.init(reader),
        };
    }

    // Public
    pub fn getRootEntry(self: *const PathResolver) !Entry {
        const root_inode = try self.reader.readInode(2);

        if (!root_inode.isDirectory()) {
            return Error.NotDirectory;
        }

        return Entry.create(2, 1, Entry.FileType.DIR, "/");
    }

    pub fn resolvePath(self: *const PathResolver, allocator: Allocator, path: []const u8) !Entry {
        if (path.len == 0) {
            return Error.EntryNotFound;
        }

        if (std.mem.eql(u8, path, "/")) {
            return self.getRootEntry();
        }

        var current_entry = try self.getRootEntry();

        var path_components = std.ArrayList([]const u8).init(allocator);
        defer path_components.deinit();

        try self.splitPath(path, &path_components);

        for (path_components.items) |component| {
            if (component.len == 0) continue;

            const next_entry = try self.findEntryInDirectory(
                allocator,
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
        self: *const PathResolver,
        allocator: Allocator,
        directory_entry: *const Entry,
        target_name: []const u8,
    ) !Entry {
        if (!directory_entry.isDirectory()) {
            return Error.NotDirectory;
        }

        if (try self.directory_reader.findInDirectory(
            allocator,
            directory_entry,
            target_name,
        )) |target_entry| {
            return target_entry;
        }

        return Error.EntryNotFound;
    }

    fn splitPath(self: *const PathResolver, path: []const u8, components: *std.ArrayList([]const u8)) !void {
        _ = self;

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
};
