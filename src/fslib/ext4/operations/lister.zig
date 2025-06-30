const std = @import("std");
const Allocator = std.mem.Allocator;

const Ext4Entry = @import("../structures/entry.zig").Entry;
const Entry = @import("../../entry.zig").Entry;
const EntryType = @import("../../entry.zig").EntryType;
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
        const dir_inode = try self.reader.readInode(entry.inode_number);
        const dir_data = try self.reader.readFileData(allocator, &dir_inode);
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

        // Convert parsed entries to filesystem entries with metadata
        var entries = std.ArrayList(Entry).init(allocator);

        for (parsed_entries) |parsed_entry| {
            if (parsed_entry.inode_number != 0) {
                const owned_name = try allocator.dupe(u8, parsed_entry.name);

                const entry_type = convertAlgorithmFileType(parsed_entry.file_type);

                const filesystem_entry = if (self.reader.readInode(parsed_entry.inode_number)) |inode| Entry{
                    .name = owned_name,
                    .entry_type = entry_type,
                    .size = inode.size(),
                    .mode = inode.i_mode,
                    .inode_number = parsed_entry.inode_number,
                } else |_| Entry{
                    .name = owned_name,
                    .entry_type = entry_type,
                    .size = 0,
                    .mode = 0,
                    .inode_number = parsed_entry.inode_number,
                };

                try entries.append(filesystem_entry);
            }
        }

        return entries.toOwnedSlice();
    }

    fn convertAlgorithmFileType(file_type: u8) EntryType {
        return switch (file_type) {
            constants.FileType.REG_FILE => .file,
            constants.FileType.DIR => .directory,
            constants.FileType.SYMLINK => .symlink,
            else => .unknown,
        };
    }
};
