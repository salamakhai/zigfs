const std = @import("std");
const constants = @import("../constants.zig");
const Entry = @import("../../entry.zig").Entry;
const EntryType = @import("../../entry.zig").EntryType;

/// Ext4 Directory Entry structure
/// Represents the on-disk format of directory entries in ext4
pub const Ext4DirEntry = extern struct {
    inode: u32, // Inode number
    record_len: u16, // Record length (includes padding)
    name_len: u8, // Name length
    file_type: u8, // File type (EXT4_FT_{type})

    pub fn getName(self: *const Ext4DirEntry, data: []const u8, offset: usize) []const u8 {
        const name_start = offset + @sizeOf(Ext4DirEntry);
        const name_end = name_start + self.name_len;
        if (name_end <= data.len) {
            return data[name_start..name_end];
        }
        return "";
    }

    pub fn toEntry(self: *const Ext4DirEntry, name: []const u8, allocator: std.mem.Allocator) !Entry {
        const owned_name = try allocator.dupe(u8, name);

        const entry_type: EntryType = switch (self.file_type) {
            constants.FileType.REG_FILE => .file,
            constants.FileType.DIR => .directory,
            constants.FileType.SYMLINK => .symlink,
            else => .unknown,
        };

        return Entry{
            .name = owned_name,
            .entry_type = entry_type,
            .size = 0,
            .mode = 0,
            .inode_number = self.inode,
        };
    }

    pub fn isValid(self: *const Ext4DirEntry) bool {
        return self.inode != 0 and
            self.record_len >= @sizeOf(Ext4DirEntry) and
            self.name_len > 0 and
            self.name_len <= 255;
    }

    pub fn nextEntry(self: *const Ext4DirEntry, current_offset: usize) usize {
        return current_offset + self.record_len;
    }
};
