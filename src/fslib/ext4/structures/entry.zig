const std = @import("std");
const EntryLayout = @import("../layout/entry_layout.zig").EntryLayout;

pub const Entry = struct {
    // Variables
    layout: EntryLayout,
    name: ?[]const u8 = null,

    // Types
    pub const FileType = EntryLayout.FILE_TYPES;

    // Lifecycle
    pub fn fromLayout(layout: EntryLayout) Entry {
        return Entry{ .layout = layout };
    }

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

    // Properties
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

    // Type Checking
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

    // Validation
    pub fn isValid(self: *const Entry) bool {
        return self.layout.inode != 0 and
            self.layout.rec_len >= @sizeOf(EntryLayout) and
            self.layout.name_len > 0 and
            self.layout.name_len <= EntryLayout.CONSTRAINTS.MAX_NAME_LEN;
    }

    /// Check if entry is deleted (inode = 0, null inode)
    pub fn isDeleted(self: *const Entry) bool {
        return self.layout.inode == 0;
    }

    /// Check if this is current directory entry (".")
    pub fn isCurrentDirectory(self: *const Entry) bool {
        const name = self.name;
        return std.mem.eql(u8, name, EntryLayout.SPECIAL_ENTRIES.CURRENT_DIR);
    }

    /// Check if this is parent directory entry ("..")
    pub fn isParentDirectory(self: *const Entry) bool {
        const name = self.name;
        return std.mem.eql(u8, name, EntryLayout.SPECIAL_ENTRIES.PARENT_DIR);
    }

    pub fn isSpecial(self: *const Entry, data: []const u8, offset: usize) bool {
        return self.isCurrentDirectory(data, offset) or self.isParentDirectory(data, offset);
    }

    // Utils
    pub fn nextEntryOffset(self: *const Entry, current_offset: usize) usize {
        return current_offset + self.recordLength();
    }

    pub fn paddingBytes(self: *const Entry) u16 {
        const used_space = @sizeOf(EntryLayout) + self.layout.name_len;
        return self.layout.rec_len - used_space;
    }

    /// Check if entry is aligned
    pub fn isAligned(self: *const Entry) bool {
        return (self.layout.rec_len % EntryLayout.CONSTRAINTS.REC_LEN_ALIGNMENT) == 0;
    }

    // Comparison
    pub fn eql(self: *const Entry, other: *const Entry) bool {
        return self.layout.inode == other.layout.inode;
    }

    pub fn nameEql(self: *const Entry, data: []const u8, offset: usize, target_name: []const u8) bool {
        const name = self.getName(data, offset);
        return std.mem.eql(u8, name, target_name);
    }

    // Debug
    pub fn format(
        self: *const Entry,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Entry{{ inode={}, type={}, name_len={} }}", .{
            self.layout.inode,
            self.fileType(),
            self.layout.name_len,
        });
    }
};
