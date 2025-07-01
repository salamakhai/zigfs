const std = @import("std");

const EntryLayout = @import("../layout/entry_layout.zig").EntryLayout;

pub const Entry = extern struct {
    layout: EntryLayout,

    pub fn convertEach(from: *[]const EntryLayout, results: *[]const Entry) bool {
        _ = from;
        _ = results;
    }

    // Public
    pub fn getName(self: *const Entry, data: []const u8, offset: usize) []const u8 {
        const name_start = offset + @sizeOf(Entry);
        const name_end = name_start + self.layout.name_len;
        if (name_end <= data.len) {
            return data[name_start..name_end];
        }
        return "";
    }

    pub fn isValid(self: *const Entry) bool {
        return self.layout.inode != 0 and
            self.layout.rec_len >= @sizeOf(Entry) and
            self.layout.name_len > 0 and
            self.layout.name_len <= EntryLayout.CONSTRAINTS.MAX_NAME_LEN;
    }

    pub fn nextEntry(self: *const Entry, current_offset: usize) usize {
        return current_offset + self.recordLength();
    }

    pub fn fileType(self: *const Entry) u8 {
        return self.layout.file_type;
    }

    pub fn inodeNumber(self: *const Entry) u32 {
        return self.layout.inode;
    }

    pub fn recordLength(self: *const Entry) u16 {
        return self.layout.rec_len;
    }

    pub fn nameLength(self: *const Entry) u8 {
        return self.layout.name_len;
    }

    pub fn isDirectory(self: *const Entry) bool {
        return self.layout.file_type == EntryLayout.FILE_TYPES.DIR;
    }

    pub fn isFile(self: *const Entry) bool {
        return self.layout.file_type == EntryLayout.FILE_TYPES.REG_FILE;
    }

    pub fn isSymlink(self: *const Entry) bool {
        return self.layout.file_type == EntryLayout.FILE_TYPES.SYMLINK;
    }

    /// Check if this is (".")
    pub fn isCurrentDirectory(self: *const Entry, data: []const u8, offset: usize) bool {
        const name = self.getName(data, offset);
        return std.mem.eql(u8, name, EntryLayout.SPECIAL_ENTRIES.CURRENT_DIR);
    }

    /// Check if this is ("..")
    pub fn isParentDirectory(self: *const Entry, data: []const u8, offset: usize) bool {
        const name = self.getName(data, offset);
        return std.mem.eql(u8, name, EntryLayout.SPECIAL_ENTRIES.PARENT_DIR);
    }
};
