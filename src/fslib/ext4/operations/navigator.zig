const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;

const EntryTraversal = @import("entry_traversal.zig").EntryTraversal;

/// Responsible for resolving filesystem paths to Entry structures
pub const Navigator = struct {
    // Variables
    reader: *const Reader,
    traversal: EntryTraversal,

    // Lifecycle
    pub fn init(reader: *const Reader) Navigator {
        return Navigator{
            .reader = reader,
            .traversal = EntryTraversal.init(reader),
        };
    }

    // Public
    /// Get root directory entry (inode 2)
    pub fn getRootEntry(self: *const Navigator) !Entry {
        const root_inode = try self.reader.readInode(2);

        if (!root_inode.isDirectory()) {
            return Error.NotDirectory;
        }

        return Entry.create(2, 1, Entry.FileType.DIR, "/");
    }

    /// Resolve a filesystem path to an Entry
    /// Path should be absolute (starting with /) or relative to root
    pub fn getEntry(self: *const Navigator, allocator: Allocator, path: []const u8) !Entry {
        if (path.len == 0) {
            return Error.EntryNotFound;
        }

        // Handle root
        if (std.mem.eql(u8, path, "/")) {
            return self.getRootEntry();
        }

        // Start from root
        var current_entry = try self.getRootEntry();

        var path_components = std.ArrayList([]const u8).init(allocator);
        defer path_components.deinit();

        try self.splitPath(path, &path_components);

        for (path_components.items) |component| {
            if (component.len == 0) continue; // Skip empty

            current_entry = try self.findEntryInDirectory(
                allocator,
                &current_entry,
                component,
            );
        }

        return current_entry;
    }

    // Private
    fn findEntryInDirectory(
        self: *const Navigator,
        allocator: Allocator,
        directory_entry: *const Entry,
        target_name: []const u8,
    ) !Entry {
        if (!directory_entry.isDirectory()) {
            return Error.NotDirectory;
        }

        if (try self.traversal.findEntry(
            allocator,
            directory_entry,
            target_name,
        )) |target_entry| {
            return target_entry;
        }

        return Error.EntryNotFound;
    }

    /// Split a path into components
    fn splitPath(self: *const Navigator, path: []const u8, components: *std.ArrayList([]const u8)) !void {
        _ = self;

        var start: usize = 0;

        // Skip slash
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
