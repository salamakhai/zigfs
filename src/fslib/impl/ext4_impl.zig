const std = @import("std");
const Allocator = std.mem.Allocator;

// Generics types
const GenericFilesystem = @import("../generic_filesystem.zig").GenericFilesystem;
const GenericEntry = @import("../generic_entry.zig").GenericEntry;
const GenericEntryType = @import("../generic_entry.zig").EntryType;
const GenericEntryMetadata = @import("../generic_entry.zig").EntryMetadata;

// Ext4 types
const ext4_fs = @import("../ext4/ext4_fs.zig");
const Ext4Fs = ext4_fs.Ext4Fs;
const Superblock = Ext4Fs.Superblock;

// ========= Public =========

pub fn detect(file: std.fs.File) bool {
    const superblock = Superblock.fromFile(file) catch {
        return false;
    };

    return superblock.isValid();
}

pub fn create(
    allocator: Allocator,
    file: std.fs.File,
) !GenericFilesystem {
    const fs = try Ext4Fs.create(allocator, file);

    const impl = GenericFilesystem{
        .context = @ptrCast(fs),

        .info = GenericFilesystem.FilesystemInfo{
            .fs_type = "ext4",
            .block_size = fs.block_size,
            .total_size = @as(u64, fs.superblock.layout.s_blocks_count_lo) * fs.block_size,
            .free_size = @as(u64, fs.superblock.layout.s_free_blocks_count_lo) * fs.block_size,
            .total_entries = fs.superblock.layout.s_inodes_count,
            .free_entries = fs.superblock.layout.s_free_inodes_count,
            .max_filename_length = 255, // EXT4 maximum filename length
            .is_readonly = true,
        },

        .list_directory = ext4ListDirectory,
        .read_file = ext4ReadFile,
        .get_path_entry = ext4GetPathEntry,
        .get_root_entry = ext4GetRootEntry,
        .onDestroy = ext4Destroy,
    };

    return impl;
}

// ========= Private =========

fn ext4EntryToGeneric(allocator: Allocator, ext4_entry: *const Ext4Fs.Entry) !GenericEntry {
    const owned_name = try allocator.dupe(u8, ext4_entry.name);

    return GenericEntry{
        .name = owned_name,
        .entry_type = ext4_entry.entry_type,
        .metadata = ext4_entry.metadata,
    };
}

fn ext4ListDirectory(context: *anyopaque, allocator: Allocator, path: []const u8) anyerror![]GenericEntry {
    const fs: *Ext4Fs = @ptrCast(@alignCast(context));

    const dir_entry = try fs.getEntry(allocator, path);
    defer allocator.free(dir_entry.name);

    const ext4_entries = try fs.extractFile(allocator, &dir_entry);

    defer {
        for (ext4_entries) |entry| {
            allocator.free(entry.name);
        }
        allocator.free(ext4_entries);
    }

    var generic_entries = try allocator.alloc(GenericEntry, ext4_entries.len);
    for (ext4_entries, 0..) |ext4_entry, i| {
        generic_entries[i] = try ext4EntryToGeneric(allocator, &ext4_entry);
    }

    return generic_entries;
}

fn ext4ReadFile(context: *anyopaque, allocator: Allocator, path: []const u8) anyerror![]u8 {
    const fs: *Ext4Fs = @ptrCast(@alignCast(context));

    const file_entry = try fs.getEntry(allocator, path);
    defer allocator.free(file_entry.name);

    return try fs.extractFile(allocator, &file_entry);
}

fn ext4GetPathEntry(context: *anyopaque, allocator: Allocator, path: []const u8) anyerror!GenericEntry {
    const fs: *Ext4Fs = @ptrCast(@alignCast(context));

    const ext4_entry = try fs.getPathEntry(allocator, path);
    defer allocator.free(ext4_entry.name);

    return try ext4EntryToGeneric(allocator, &ext4_entry);
}

fn ext4GetRootEntry(context: *anyopaque, allocator: Allocator) anyerror!GenericEntry {
    const fs: *Ext4Fs = @ptrCast(@alignCast(context));

    const root_entry = try fs.getRootEntry(allocator);
    defer allocator.free(root_entry.name);

    return try ext4EntryToGeneric(allocator, &root_entry);
}

fn ext4Destroy(context: *anyopaque) void {
    const fs: *Ext4Fs = @ptrCast(@alignCast(context));
    fs.destroy();
}
