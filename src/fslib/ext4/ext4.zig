const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const DiskReader = @import("disk/reader.zig").Reader;

pub const Ext4 = struct {
    // Types
    pub const Superblock = @import("types/superblock.zig").Superblock;
    pub const EntryContext = @import("types/entry_context.zig").EntryContext;
    pub const Entry = @import("types/entry.zig").Entry;
    pub const Inode = @import("types/inode.zig").Inode;
    pub const Error = @import("error.zig").Ext4Error;

    const reader = @import("operations/reader.zig");
    const resolver = @import("operations/resolver.zig");
    const walker = @import("operations/walker.zig");
    const entries_parsing = @import("parsing/entries.zig");

    // Fields
    file: fs.File,
    allocator: Allocator,
    filename: []u8,

    superblock: Superblock,
    disk_reader: DiskReader,

    // Lifecycle
    pub fn detect(file: fs.File) bool {
        return Superblock.detect(file);
    }

    pub fn create(allocator: Allocator, file: fs.File, filename: []const u8) !*Ext4 {
        const superblock = try Superblock.create(file);
        const filesystem = try allocator.create(Ext4);

        // TODO -- Temp solution: in the future get volume name from superblock instead
        const basename = std.fs.path.basename(filename);
        const maybe_index = std.mem.lastIndexOf(u8, basename, ".");
        const formatted_name = if (maybe_index) |dot_index| basename[0..dot_index] else basename;

        filesystem.* = Ext4{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
            .filename = try allocator.dupe(u8, formatted_name),
            .disk_reader = DiskReader.init(allocator, file, superblock.blockSize()),
        };

        return filesystem;
    }

    pub fn destroy(self: *Ext4) void {
        self.file.close();
        self.allocator.free(self.filename);
        self.allocator.destroy(self);
    }

    // Public
    pub fn getFileName(self: *Ext4) []const u8 {
        return self.filename;
    }

    pub fn getOwnedFileName(allocator: Allocator, self: *Ext4) ![]u8 {
        return allocator.dupe(u8, self.filename);
    }

    pub fn getRootEntry(self: *Ext4) !Entry {
        return resolver.getRootEntry(&self.disk_reader, &self.superblock);
    }

    pub fn getEntry(self: *Ext4, allocator: Allocator, path: []const u8) !Entry {
        return resolver.resolvePath(
            allocator,
            &self.disk_reader,
            &self.superblock,
            path,
        );
    }

    pub fn readFile(self: *Ext4, allocator: Allocator, entry: *const Entry) ![]u8 {
        return reader.readContent(
            allocator,
            &self.disk_reader,
            &self.superblock,
            entry,
        );
    }

    pub fn readFilePartial(
        self: *Ext4,
        allocator: Allocator,
        entry: *const Entry,
        offset: u64,
        size: u64,
    ) ![]u8 {
        return reader.readContentPartial(
            allocator,
            &self.disk_reader,
            &self.superblock,
            entry,
            offset,
            size,
        );
    }

    pub fn getFileSize(self: *Ext4, entry: *const Entry) !u64 {
        return reader.getSize(&self.disk_reader, &self.superblock, entry);
    }

    pub fn isFileReadable(self: *Ext4, entry: *const Entry) bool {
        return reader.isReadable(&self.disk_reader, &self.superblock, entry);
    }

    pub fn readDirectoryContext(self: *Ext4, allocator: Allocator, entry: *const Entry) !EntryContext {
        return walker.readDirectoryContext(
            allocator,
            &self.disk_reader,
            &self.superblock,
            entry,
        );
    }

    pub fn findInDirectory(
        self: *Ext4,
        allocator: Allocator,
        directory_entry: *const Entry,
        target_name: []const u8,
    ) !?Entry {
        return walker.findInDirectory(
            allocator,
            &self.disk_reader,
            &self.superblock,
            directory_entry,
            target_name,
        );
    }
};
