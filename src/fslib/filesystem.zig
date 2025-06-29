const std = @import("std");

const Ext4FileSystem = @import("ext4/ext4_filesystem.zig").Ext4FileSystem;
const Entry = @import("entry.zig").Entry;
const errors = @import("errors.zig");

const EXT4_MAGIC_NUMBER: u16 = 0xEF53;

pub const FileSystem = union(enum) {
    // Fields
    ext4: *Ext4FileSystem,

    // Lifecycle
    pub fn create(allocator: std.mem.Allocator, file: std.fs.File) !FileSystem {
        const magic = try detectMagic(file);

        switch (magic) {
            EXT4_MAGIC_NUMBER => {
                const ext4_fs = try Ext4FileSystem.create(allocator, file);
                return .{
                    .ext4 = ext4_fs,
                };
            },
            else => {
                return errors.FileSystemError.UnsupportedFormat;
            },
        }
    }

    pub fn destroy(self: *FileSystem) void {
        switch (self.*) {
            .ext4 => |fs| fs.destroy(),
        }
    }

    // Public
    pub fn getRootEntry(self: *FileSystem, allocator: std.mem.Allocator) !Entry {
        switch (self.*) {
            .ext4 => |fs| return fs.getRootEntry(allocator),
        }
    }

    pub fn getPathEntry(self: *FileSystem, allocator: std.mem.Allocator, path: []const u8) !Entry {
        switch (self.*) {
            .ext4 => |fs| return fs.getPathEntry(allocator, path),
        }
    }

    pub fn readEntryAsFile(self: *FileSystem, allocator: std.mem.Allocator, entry: *const Entry) ![]u8 {
        if (!entry.isFile()) {
            return errors.FileSystemError.NotFile;
        }

        switch (self.*) {
            .ext4 => |fs| return fs.readEntryAsFile(allocator, entry),
        }
    }

    pub fn readEntryAsDirectory(self: *FileSystem, allocator: std.mem.Allocator, entry: *const Entry) ![]Entry {
        if (!entry.isDirectory()) {
            return errors.FileSystemError.NotDirectory;
        }

        switch (self.*) {
            .ext4 => |fs| return fs.readEntryAsDirectory(allocator, entry),
        }
    }

    // Private
    fn detectMagic(file: std.fs.File) !u16 {
        try file.seekTo(1024 + 56);
        var magic_bytes: [2]u8 = undefined;
        _ = try file.read(&magic_bytes);

        return std.mem.readInt(u16, &magic_bytes, .little);
    }
};
