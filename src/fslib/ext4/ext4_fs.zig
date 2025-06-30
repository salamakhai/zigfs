const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Superblock = @import("structures/superblock.zig").Superblock;
const Entry = @import("../entry.zig").Entry;
const Reader = @import("operations/reader.zig").Reader;
const Navigator = @import("operations/navigator.zig").Navigator;
const DirectoryLister = @import("operations/lister.zig").DirectoryLister;
const FileExtractor = @import("operations/extractor.zig").FileExtractor;

pub const Ext4FS = struct {
    // Fields
    file: fs.File,
    superblock: Superblock,
    allocator: Allocator,
    block_size: u32,

    reader: Reader,
    navigator: Navigator,
    lister: DirectoryLister,
    extractor: FileExtractor,

    // Lifecycle
    pub fn create(allocator: Allocator, file: fs.File) !*Ext4FS {
        const superblock = try Superblock.fromFile(file);
        const filesystem = try allocator.create(Ext4FS);

        filesystem.* = Ext4FS{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
            .block_size = superblock.blockSize(),
            .reader = undefined,
            .navigator = undefined,
            .lister = undefined,
            .extractor = undefined,
        };

        filesystem.reader = Reader.init(file, &filesystem.superblock);
        filesystem.navigator = Navigator.init(&filesystem.reader);
        filesystem.lister = DirectoryLister.init(&filesystem.reader);
        filesystem.extractor = FileExtractor.init(&filesystem.reader);

        return filesystem;
    }

    pub fn destroy(self: *Ext4FS) void {
        self.file.close();
        self.allocator.destroy(self);
    }

    // Public
    pub fn getRootEntry(self: *Ext4FS, allocator: Allocator) !Entry {
        return self.navigator.getRootEntry(allocator);
    }

    pub fn getPathEntry(self: *Ext4FS, allocator: Allocator, path: []const u8) !Entry {
        return self.navigator.getEntry(allocator, path);
    }

    pub fn readEntryAsFile(self: *Ext4FS, allocator: Allocator, entry: *const Entry) ![]u8 {
        return self.extractor.extractFile(allocator, entry);
    }

    pub fn readEntryAsDirectory(self: *Ext4FS, allocator: Allocator, entry: *const Entry) ![]Entry {
        return self.lister.listDirectory(allocator, entry);
    }
};
