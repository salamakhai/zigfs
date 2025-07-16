const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;

pub const FileOperations = struct {
    reader: *const Reader,

    pub fn init(reader: *const Reader) FileOperations {
        return FileOperations{
            .reader = reader,
        };
    }

    pub fn readContent(self: *const FileOperations, entry: *const Entry) ![]u8 {
        if (!entry.isFile()) {
            return Error.NotFile;
        }

        const inode_number = entry.inodeNumber();
        const file_inode = try self.reader.readInode(inode_number);

        if (!file_inode.isRegularFile()) {
            return Error.NotFile;
        }

        return self.reader.readInodeData(&file_inode);
    }

    pub fn readContentPartial(
        self: *const FileOperations,
        allocator: Allocator,
        entry: *const Entry,
        offset: u64,
        size: u64,
    ) ![]u8 {
        if (!entry.isFile()) {
            return Error.NotFile;
        }

        const full_data = try self.readContent(entry);
        defer allocator.free(full_data);

        if (offset >= full_data.len) {
            return try allocator.alloc(u8, 0);
        }

        const start = offset;
        const end = @min(offset + size, full_data.len);
        const partial_size = end - start;

        const partial_data = try allocator.alloc(u8, partial_size);
        @memcpy(partial_data, full_data[start..end]);

        return partial_data;
    }

    pub fn getSize(self: *const FileOperations, entry: *const Entry) !u64 {
        if (!entry.isFile()) {
            return Error.NotFile;
        }

        const inode_number = entry.inodeNumber();
        const file_inode = try self.reader.readInode(inode_number);

        if (!file_inode.isRegularFile()) {
            return Error.NotFile;
        }

        return file_inode.size();
    }

    pub fn isReadable(self: *const FileOperations, entry: *const Entry) !bool {
        if (!entry.isFile()) {
            return false;
        }

        const inode_number = entry.inodeNumber();
        const file_inode = self.reader.readInode(inode_number) catch {
            return false;
        };

        return file_inode.isRegularFile();
    }
};
