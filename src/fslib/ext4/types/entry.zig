const std = @import("std");
const Allocator = std.mem.Allocator;
const EntryLayout = @import("../disk/layout.zig").EntryLayout;

pub const Entry = struct {
    layout: EntryLayout,
    name: ?[]const u8 = null,

    pub const FileType = EntryLayout.FILE_TYPES;

    pub fn create(inode_number: u32, name_len: u8, file_type: u8, name: []const u8) Entry {
        return Entry{
            .layout = EntryLayout{
                .inode = inode_number,
                .rec_len = @sizeOf(EntryLayout) + name_len,
                .name_len = name_len,
                .file_type = file_type,
            },
            .name = name,
        };
    }

    pub fn getCachedName(self: *const Entry) []const u8 {
        return self.name;
    }

    pub fn getName(self: *const Entry, directory_data: []const u8, entry_offset: usize) []const u8 {
        const name_start = entry_offset + @sizeOf(EntryLayout);
        const name_end = name_start + self.layout.name_len;

        if (name_end <= directory_data.len) {
            return directory_data[name_start..name_end];
        }

        return &[_]u8{};
    }

    pub fn getOwnedName(self: *const Entry, allocator: Allocator, directory_data: []const u8, entry_offset: usize) ![]u8 {
        const name_slice = self.getName(directory_data, entry_offset);
        if (name_slice.len == 0) {
            return error.InvalidName;
        }
        return try allocator.dupe(u8, name_slice);
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

    pub fn rawFileType(self: *const Entry) u8 {
        return self.layout.file_type;
    }

    pub fn fileType(self: *const Entry) u8 {
        return self.layout.file_type;
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

    pub fn isCharacterDevice(self: *const Entry) bool {
        return self.layout.file_type == EntryLayout.FILE_TYPES.CHRDEV;
    }

    pub fn isBlockDevice(self: *const Entry) bool {
        return self.layout.file_type == EntryLayout.FILE_TYPES.BLKDEV;
    }

    pub fn isFifo(self: *const Entry) bool {
        return self.layout.file_type == EntryLayout.FILE_TYPES.FIFO;
    }

    pub fn isSocket(self: *const Entry) bool {
        return self.layout.file_type == EntryLayout.FILE_TYPES.SOCK;
    }

    pub fn isDevice(self: *const Entry) bool {
        return self.isCharacterDevice() or self.isBlockDevice();
    }

    pub fn isValid(self: *const Entry) bool {
        return self.layout.inode != 0 and
            self.layout.rec_len >= @sizeOf(EntryLayout) and
            self.layout.name_len > 0 and
            self.layout.name_len <= EntryLayout.CONSTRAINTS.MAX_NAME_LEN;
    }

    pub fn isDeleted(self: *const Entry) bool {
        return self.layout.inode == 0;
    }

    pub fn isCurrentDirectory(self: *const Entry, directory_data: []const u8, entry_offset: usize) bool {
        const name = self.getName(directory_data, entry_offset);
        return std.mem.eql(u8, name, EntryLayout.SPECIAL_ENTRIES.CURRENT_DIR);
    }

    pub fn isParentDirectory(self: *const Entry, directory_data: []const u8, entry_offset: usize) bool {
        const name = self.getName(directory_data, entry_offset);
        return std.mem.eql(u8, name, EntryLayout.SPECIAL_ENTRIES.PARENT_DIR);
    }

    pub fn isSpecial(self: *const Entry, directory_data: []const u8, entry_offset: usize) bool {
        return self.isCurrentDirectory(directory_data, entry_offset) or self.isParentDirectory(directory_data, entry_offset);
    }

    pub fn nextEntryOffset(self: *const Entry, current_offset: usize) usize {
        return current_offset + self.recordLength();
    }

    pub fn paddingBytes(self: *const Entry) u16 {
        const used_space = @sizeOf(EntryLayout) + self.layout.name_len;
        return self.layout.rec_len - used_space;
    }

    pub fn isAligned(self: *const Entry) bool {
        return (self.layout.rec_len % EntryLayout.CONSTRAINTS.REC_LEN_ALIGNMENT) == 0;
    }

    pub fn eql(self: *const Entry, other: *const Entry) bool {
        return self.layout.inode == other.layout.inode;
    }

    pub fn nameEql(self: *const Entry, data: []const u8, offset: usize, target_name: []const u8) bool {
        const name = self.getName(data, offset);
        return std.mem.eql(u8, name, target_name);
    }
};
