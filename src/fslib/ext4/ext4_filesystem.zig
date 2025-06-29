const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Superblock = @import("structures/superblock.zig").Superblock;
const Entry = @import("../entry.zig").Entry;
const Reader = @import("operations/reader.zig").Reader;
const Navigator = @import("operations/navigator.zig").Navigator;
const Lister = @import("operations/lister.zig").Lister;
const Extractor = @import("operations/extractor.zig").Extractor;

pub const Ext4FileSystem = struct {
    // Fields
    file: fs.File,
    superblock: Superblock,
    allocator: Allocator,
    block_size: u32,

    reader: Reader,
    navigator: Navigator,
    lister: Lister,
    extractor: Extractor,

    // Lifecycle
    pub fn create(allocator: Allocator, file: fs.File) !*Ext4FileSystem {
        const superblock = try Superblock.fromFile(file);
        const filesystem = try allocator.create(Ext4FileSystem);

        filesystem.* = Ext4FileSystem{
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
        filesystem.lister = Lister.init(&filesystem.reader);
        filesystem.extractor = Extractor.init(&filesystem.reader);

        return filesystem;
    }

    pub fn destroy(self: *Ext4FileSystem) void {
        self.file.close();
        self.allocator.destroy(self);
    }

    // Public
    pub fn getRootEntry(self: *Ext4FileSystem, allocator: Allocator) !Entry {
        return self.navigator.getRootEntry(allocator);
    }

    pub fn getPathEntry(self: *Ext4FileSystem, allocator: Allocator, path: []const u8) !Entry {
        return self.navigator.getEntry(allocator, path);
    }

    pub fn readEntryAsFile(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]u8 {
        return self.extractor.readFile(allocator, entry);
    }

    pub fn readEntryAsDirectory(self: *Ext4FileSystem, allocator: Allocator, entry: *const Entry) ![]Entry {
        return self.lister.listDirectory(allocator, entry);
    }
};
