const std = @import("std");
const constants = @import("../constants.zig");

/// Represents the on-disk format of directory entries in ext4
pub const Entry = extern struct {
    inode: u32, // Inode number
    record_len: u16, // Record length (includes padding)
    name_len: u8, // Name length
    file_type: u8, // File type (EXT4_FT_{type})

    pub fn getName(self: *const Entry, data: []const u8, offset: usize) []const u8 {
        const name_start = offset + @sizeOf(Entry);
        const name_end = name_start + self.name_len;
        if (name_end <= data.len) {
            return data[name_start..name_end];
        }
        return "";
    }

    pub fn isValid(self: *const Entry) bool {
        return self.inode != 0 and
            self.record_len >= @sizeOf(Entry) and
            self.name_len > 0 and
            self.name_len <= 255;
    }

    pub fn nextEntry(self: *const Entry, current_offset: usize) usize {
        return current_offset + self.record_len;
    }
};
