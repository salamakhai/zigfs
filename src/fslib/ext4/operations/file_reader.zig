const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;

pub const FileReader = struct {
    // === Variables ===
    reader: *const Reader,

    // === Lifecycle ===
    pub fn init(reader: *const Reader) FileReader {
        return FileReader{
            .reader = reader,
        };
    }

    // === Public ===
    /// Read complete file contents
    /// Returns owned buffer with file data
    pub fn readFile(self: *const FileReader, entry: *const Entry) ![]u8 {
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

    /// Read partial file contents
    /// Reads 'size' bytes starting from 'offset'
    pub fn readFilePartial(
        self: *const FileReader,
        allocator: Allocator,
        entry: *const Entry,
        offset: u64,
        size: u64,
    ) ![]u8 {
        if (!entry.isFile()) {
            return Error.NotFile;
        }

        const full_data = try self.readFile(allocator, entry);
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

    /// Get file size without reading content
    pub fn getFileSize(self: *const FileReader, entry: *const Entry) !u64 {
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

    pub fn isReadableFile(self: *const FileReader, entry: *const Entry) !bool {
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