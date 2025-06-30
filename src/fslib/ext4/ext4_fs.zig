const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Reader = @import("operations/reader.zig").Reader;
const Navigator = @import("operations/navigator.zig").Navigator;
const DirectoryLister = @import("operations/lister.zig").DirectoryLister;
const FileExtractor = @import("operations/extractor.zig").FileExtractor;

pub const Ext4Fs = struct {
    // Types
    pub const Superblock = @import("structures/superblock.zig").Superblock;
    pub const Entry = @import("structures/entry.zig").Entry;

    // Vaiables
    file: fs.File,
    allocator: Allocator,

    // Structures
    superblock: Superblock,

    // Operations
    reader: Reader,
    navigator: Navigator,
    lister: DirectoryLister,
    extractor: FileExtractor,

    // Lifecycle
    pub fn create(allocator: Allocator, file: fs.File) !*Ext4Fs {
        const superblock = try Superblock.fromFile(file);
        const filesystem = try allocator.create(Ext4Fs);

        filesystem.* = Ext4Fs{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
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

    pub fn destroy(self: *Ext4Fs) void {
        self.file.close();
        self.allocator.destroy(self);
    }

    // Public
    pub fn getRootEntry(self: *Ext4Fs, allocator: Allocator) !Entry {
        return self.navigator.getRootEntry(allocator);
    }

    pub fn getEntry(self: *Ext4Fs, allocator: Allocator, path: []const u8) !Entry {
        return self.navigator.getEntry(allocator, path);
    }

    pub fn extractFile(self: *Ext4Fs, allocator: Allocator, entry: *const Entry) ![]u8 {
        return self.extractor.extractFile(allocator, entry);
    }

    pub fn listDirectory(self: *Ext4Fs, allocator: Allocator, entry: *const Entry) ![]Entry {
        return self.lister.listDirectory(allocator, entry);
    }
};
