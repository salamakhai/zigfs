const std = @import("std");
const Allocator = std.mem.Allocator;

const Ext4Entry = @import("../structures/entry.zig").Entry;
const Entry = @import("../../entry.zig").Entry;
const EntryType = @import("../../entry.zig").EntryType;
const Reader = @import("reader.zig").Reader;
const constants = @import("../constants.zig");
const errors = @import("../../errors.zig");

pub const Lister = struct {
    reader: *const Reader,

    pub fn init(reader: *const Reader) Lister {
        return Lister{
            .reader = reader,
        };
    }

    pub fn listDirectory(self: *const Lister, allocator: Allocator, entry: *const Entry) ![]Entry {
        if (!entry.isDirectory()) {
            return errors.FileSystemError.NotDirectory;
        }

        const dir_inode = try self.reader.readInode(entry.inode_number);
        const dir_data = try self.reader.readInodeData(allocator, &dir_inode);
        defer allocator.free(dir_data);

        var entries = std.ArrayList(Entry).init(allocator);
        var offset: usize = 0;

        while (offset < dir_data.len) {
            if (offset + @sizeOf(Ext4Entry) > dir_data.len) {
                break;
            }

            var dir_entry: Ext4Entry = undefined;
            const entry_bytes = std.mem.asBytes(&dir_entry);
            const available_bytes = @min(entry_bytes.len, dir_data.len - offset);

            @memcpy(
                entry_bytes[0..available_bytes],
                dir_data[offset .. offset + available_bytes],
            );

            if (!dir_entry.isValid() or dir_entry.record_len == 0) {
                break;
            }

            if (offset + dir_entry.record_len > dir_data.len) {
                break;
            }

            if (dir_entry.inode != 0) {
                const name = dir_entry.getName(dir_data, offset);
                const owned_name = try allocator.dupe(u8, name);
                
                // Convert ext4 file type to generic entry type
                const entry_type: EntryType = switch (dir_entry.file_type) {
                    constants.FileType.REG_FILE => .file,
                    constants.FileType.DIR => .directory,
                    constants.FileType.SYMLINK => .symlink,
                    else => .unknown,
                };
                
                // Read inode to get complete metadata
                const filesystem_entry = if (self.reader.readInode(dir_entry.inode)) |inode| Entry{
                    .name = owned_name,
                    .entry_type = entry_type,
                    .size = inode.size(),
                    .mode = inode.i_mode,
                    .inode_number = dir_entry.inode,
                } else |_| Entry{
                    .name = owned_name,
                    .entry_type = entry_type,
                    .size = 0,
                    .mode = 0,
                    .inode_number = dir_entry.inode,
                };

                try entries.append(filesystem_entry);
            }

            offset = dir_entry.nextEntry(offset);
        }

        return entries.toOwnedSlice();
    }
};