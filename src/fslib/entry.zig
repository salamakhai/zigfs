const std = @import("std");

pub const EntryType = enum {
    file,
    directory,
    symlink,
    unknown,
};

pub const Entry = struct {
    name: []const u8,
    entry_type: EntryType,
    size: u64,
    mode: u16,
    inode_number: u32,

    pub fn isFile(self: *const Entry) bool {
        return self.entry_type == .file;
    }

    pub fn isDirectory(self: *const Entry) bool {
        return self.entry_type == .directory;
    }
};
