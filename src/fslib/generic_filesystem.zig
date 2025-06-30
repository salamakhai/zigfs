const std = @import("std");
const Allocator = std.mem.Allocator;

const GenericEntry = @import("generic_entry.zig").GenericEntry;

pub const GenericFilesystem = struct {
    // Implementations
    const ext4 = @import("./impl/ext4_impl.zig");

    /// Context pointer
    context: *anyopaque,

    info: FilesystemInfo,

    // Operations
    list_directory: *const fn(context: *anyopaque, allocator: Allocator, path: []const u8) anyerror![]GenericEntry,
    read_file: *const fn(context: *anyopaque, allocator: Allocator, path: []const u8) anyerror![]u8,
    get_path_entry: *const fn(context: *anyopaque, allocator: Allocator, path: []const u8) anyerror!GenericEntry,
    get_root_entry: *const fn(context: *anyopaque, allocator: Allocator) anyerror!GenericEntry,

    /// Called when the generic filesystem is being destroyed
    onDestroy: *const fn(context: *anyopaque) void,

    pub const FilesystemInfo = extern struct {
        fs_type: []const u8,
        block_size: u32,
        total_size: u64,
        free_size: ?u64,
        total_entries: ?u64,
        free_entries: ?u64,
        max_filename_length: u64,
        is_readonly: bool,
    };

    // Lifecycle
    pub fn create(
        allocator: Allocator,
        file: std.fs.File,
    ) !GenericFilesystem {

        if (ext4.detect(file)) {
            const ext4_impl = try ext4.create(allocator, file);
            return GenericFilesystem{
                .operations = ext4_impl.operations,
                .info = ext4_impl.info,
            };
        }

        return error.UnsupportedFilesystem;
    }

    pub fn destroy(self: *GenericFilesystem) void {
        self.onDestroy(self.operations.context);
    }

    // Public
    pub fn getInfo(self: *const GenericFilesystem) FilesystemInfo {
        return self.info;
    }

    pub fn getRootEntry(self: *const GenericFilesystem, allocator: Allocator) !GenericEntry {
        return self.operations.get_root_entry(self.operations.context, allocator);
    }

    pub fn getPathEntry(self: *const GenericFilesystem, allocator: Allocator, path: []const u8) !GenericEntry {
        return self.operations.get_path_entry(self.operations.context, allocator, path);
    }

    pub fn listDirectory(self: *const GenericFilesystem, allocator: Allocator, path: []const u8) ![]GenericEntry {
        return self.list_directory(self.operations.context, allocator, path);
    }

    pub fn readFile(self: *const GenericFilesystem, allocator: Allocator, path: []const u8) ![]u8 {
        return self.read_file(self.operations.context, allocator, path);
    }

    pub fn readEntryAsFile(self: *const GenericFilesystem, allocator: Allocator, entry: *const GenericEntry) ![]u8 {
        return self.readFile(allocator, entry.name);
    }

    pub fn readEntryAsDirectory(self: *const GenericFilesystem, allocator: Allocator, entry: *const GenericEntry) ![]GenericEntry {
        return self.listDirectory(allocator, entry.name);
    }
};
