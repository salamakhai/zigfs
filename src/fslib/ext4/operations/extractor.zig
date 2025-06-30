const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../../entry.zig").Entry;
const Reader = @import("reader.zig").Reader;
const errors = @import("../../errors.zig");

pub const FileExtractor = struct {
    reader: *const Reader,

    pub fn init(reader: *const Reader) FileExtractor {
        return FileExtractor{
            .reader = reader,
        };
    }

    pub fn extractFile(self: *const FileExtractor, allocator: Allocator, entry: *const Entry) ![]u8 {
        if (!entry.isFile()) {
            return errors.FileSystemError.ReadError;
        }

        const file_inode = try self.reader.readInode(entry.inode_number);
        return self.reader.readFileData(allocator, &file_inode);
    }
};