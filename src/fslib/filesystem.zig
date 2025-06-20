const std = @import("std");
const Entry = @import("entry.zig").Entry;
const errors = @import("errors.zig");

const Ext4FileSystem = @import("ext4/filesystem.zig").Ext4FileSystem;

pub const FileSystem = union(enum) {
    ext4: *Ext4FileSystem,

    pub fn fromFile(allocator: std.mem.Allocator, file: std.fs.File) !FileSystem {
        // Try to detect magic number to determine filesystem type
        const magic = try detectMagic(file);

        switch (magic) {
            0xEF53 => {
                const ext4_fs = try Ext4FileSystem.init(allocator, file);
                return .{
                    .ext4 = ext4_fs,
                };
            },
            else => {
                return errors.FileSystemError.UnsupportedFormat;
            },
        }
    }

    pub fn getRootEntry(self: *FileSystem, allocator: std.mem.Allocator) !Entry {
        switch (self.*) {
            .ext4 => |fs| return fs.getRootEntry(allocator),
        }
    }

    pub fn getEntry(self: *FileSystem, allocator: std.mem.Allocator, path: []const u8) !Entry {
        switch (self.*) {
            .ext4 => |fs| return fs.getEntry(allocator, path),
        }
    }

    pub fn readFile(self: *FileSystem, allocator: std.mem.Allocator, entry: *const Entry) ![]u8 {
        if (!entry.isFile()) {
            return errors.FileSystemError.ReadError;
        }

        switch (self.*) {
            .ext4 => |fs| return fs.readFile(allocator, entry),
        }
    }

    pub fn listDirectory(self: *FileSystem, allocator: std.mem.Allocator, entry: *const Entry) ![]Entry {
        if (!entry.isDirectory()) {
            return errors.FileSystemError.ReadError;
        }

        switch (self.*) {
            .ext4 => |fs| return fs.listDirectory(allocator, entry),
        }
    }

    pub fn deinit(self: *FileSystem) void {
        switch (self.*) {
            .ext4 => |fs| fs.deinit(),
        }
    }
};

/// Magic Numbers by Filesystem table
///
/// | Filesystem | Magic      | Offset   | Size    |
/// |------------|------------|----------|---------|
/// | ext2/3/4   | 0xEF53     | 1024+56  | 2 bytes | superblock offset + magic offset
/// | NTFS       | "NTFS    " | 3        | 8 bytes |
/// | FAT32      | 0x28/0x29  | 66/82    | 1 byte  |
///
fn detectMagic(file: std.fs.File) !u16 {
    try file.seekTo(1024 + 56);

    var magic_bytes: [2]u8 = undefined;
    _ = try file.read(&magic_bytes);

    return std.mem.readInt(u16, &magic_bytes, .little);
}
