const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;
const EntryLayout = @import("../layout/entry_layout.zig").EntryLayout;

/// Path resolution and directory traversal
pub const EntryTraversal = struct {
    // Variables
    reader: *const Reader,

    // Lifecycle
    pub fn init(reader: *const Reader) EntryTraversal {
        return EntryTraversal{
            .reader = reader,
        };
    }

    // Public
    pub fn listDirectory(
        self: *const EntryTraversal,
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

        // Read directory data
        const directory_data = try self.reader.readInodeData(&inode);
        defer allocator.free(directory_data);

        // Parse entries
        return try self.parseDirectoryData(allocator, directory_data);
    }

    fn parseDirectoryData(
        self: *const EntryTraversal,
        allocator: Allocator,
        directory_data: []const u8,
    ) ![]Entry {
        _ = self;

        var entries = std.ArrayList(Entry).init(allocator);
        defer {
            for (entries.items) |*entry| {
                if (entry.name) |name| {
                    allocator.free(name);
                }
            }
            entries.deinit();
        }

        var offset: usize = 0;

        while (offset < directory_data.len) {
            // Ensure there are enough data
            if (offset + @sizeOf(EntryLayout) > directory_data.len) {
                break;
            }

            // Parse entry layout
            const entry_layout = @as(*const EntryLayout, @ptrCast(@alignCast(&directory_data[offset])));

            // Validate entry
            if (!isValidEntry(entry_layout, directory_data.len - offset)) {
                break;
            }

            // Skip deleted entries (null inode)
            if (entry_layout.inode == 0) {
                offset += entry_layout.rec_len;
                continue;
            }

            // Extract name

            const name_start = offset + @sizeOf(EntryLayout);
            const name_end = name_start + entry_layout.name_len;

            if (name_end <= directory_data.len) {
                const name = try allocator.dupe(u8, directory_data[name_start..name_end]);

                const entry = Entry{
                    .layout = entry_layout.*,
                    .name = name,
                };

                try entries.append(entry);
            }

            offset += entry_layout.rec_len;
        }

        const result = try entries.toOwnedSlice();
        return result;
    }

    /// Find entry by name in directory
    pub fn findEntry(
        self: *const EntryTraversal,
        allocator: Allocator,
        directory_entry: *const Entry,
        target_name: []const u8,
    ) !?Entry {
        const entries = try self.listDirectory(allocator, directory_entry);
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
                    };
                }
            }
        }

        return null;
    }

    /// Validate directory entry structure
    fn isValidEntry(entry: *const EntryLayout, available_data: usize) bool {
        // Check basic constraints
        if (entry.rec_len < @sizeOf(EntryLayout)) {
            return false;
        }

        if (entry.name_len > EntryLayout.CONSTRAINTS.MAX_NAME_LEN) {
            return false;
        }

        // Record length must be aligned
        if (entry.rec_len % EntryLayout.CONSTRAINTS.REC_LEN_ALIGNMENT != 0) {
            return false;
        }

        // Entry must fit within available data
        if (entry.rec_len > available_data) {
            return false;
        }

        // Name must fit within record length
        const name_space_needed = @sizeOf(EntryLayout) + entry.name_len;
        if (name_space_needed > entry.rec_len) {
            return false;
        }

        return true;
    }
};
