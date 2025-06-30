const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const FilesystemEntry = @import("../structures/filesystem_entry.zig").FilesystemEntry;
const Reader = @import("reader.zig").Reader;
const constants = @import("../constants.zig");
const errors = @import("../../errors.zig");

const DirectoryTraversalAlgorithm = @import("../algorithms/directory_traversal.zig").DirectoryTraversalAlgorithm;

pub const DirectoryLister = struct {
    reader: *const Reader,

    pub fn init(reader: *const Reader) DirectoryLister {
        return DirectoryLister{
            .reader = reader,
        };
    }

    pub fn listDirectory(self: *const DirectoryLister, allocator: Allocator, entry: *const Entry) ![]Entry {
        if (!entry.isDirectory()) {
            return errors.FileSystemError.NotDirectory;
        }

        // Read directory data
        const dir_inode = try self.reader.readInode(
            @intCast(entry.getFilesystemId() orelse return errors.FileSystemError.EntryNotFound),
        );

        const dir_data = try self.reader.readFileData(
            allocator,
            &dir_inode,
        );

        defer allocator.free(dir_data);

        const parsed_entries = try DirectoryTraversalAlgorithm.parseDirectoryEntries(
            dir_data,
            allocator,
        );

        defer {
            for (parsed_entries) |parsed_entry| {
                allocator.free(parsed_entry.name);
            }
            allocator.free(parsed_entries);
        }

        var entries = std.ArrayList(Entry).init(allocator);

        for (parsed_entries) |parsed_entry| {
            if (parsed_entry.inode_number != 0) {
                const owned_name = try allocator.dupe(u8, parsed_entry.name);

                const entry_type = convertAlgorithmFileType(parsed_entry.file_type);

                const filesystem_entry = if (self.reader.readInode(parsed_entry.inode_number)) |inode| Entry{
                    .name = owned_name,
                    .entry_type = entry_type,
                    .metadata = .{
                        .size = inode.size(),
                        .mode = inode.i_mode,
                        .filesystem_id = parsed_entry.inode_number,
                        .created_time = null,
                        .modified_time = null,
                        .accessed_time = null,
                    },
                } else |_| Entry{
                    .name = owned_name,
                    .entry_type = entry_type,
                    .metadata = .{
                        .size = 0,
                        .mode = 0,
                        .filesystem_id = parsed_entry.inode_number,
                        .created_time = null,
                        .modified_time = null,
                        .accessed_time = null,
                    },
                };

                try entries.append(filesystem_entry);
            }
        }

        return entries.toOwnedSlice();
    }
};
