const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Reader = @import("operations/reader.zig").Reader;
const Navigator = @import("operations/navigator.zig").Navigator;
const EntryTraversal = @import("operations/entry_traversal.zig").EntryTraversal;
const FileReader = @import("operations/file_reader.zig").FileReader;

pub const Ext4Fs = struct {
    // === Types ===
    pub const Superblock = @import("structures/superblock.zig").Superblock;
    pub const Entry = @import("structures/entry.zig").Entry;
    pub const Error = @import("ext4_error.zig").Ext4Error;

    // === Vaiables ===
    file: fs.File,
    allocator: Allocator,

    // Structures
    superblock: Superblock,

    // Operations
    reader: Reader,
    navigator: Navigator,
    lister: EntryTraversal,
    file_reader: FileReader,

    // === Lifecycle ===
    pub fn create(allocator: Allocator, file: fs.File) !*Ext4Fs {
        const superblock = try Superblock.create(file);
        const filesystem = try allocator.create(Ext4Fs);

        filesystem.* = Ext4Fs{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
            .reader = undefined,
            .navigator = undefined,
            .lister = undefined,
            .file_reader = undefined,
        };

        filesystem.reader = Reader.init(allocator, file, &filesystem.superblock);
        filesystem.navigator = Navigator.init(&filesystem.reader);
        filesystem.lister = EntryTraversal.init(&filesystem.reader);
        filesystem.file_reader = FileReader.init(&filesystem.reader);

        return filesystem;
    }

    pub fn destroy(self: *Ext4Fs) void {
        self.file.close();
        self.allocator.destroy(self);
    }

    // === Public ===
    pub fn getRootEntry(self: *Ext4Fs) !Entry {
        return self.navigator.getRootEntry();
    }

    pub fn getEntry(self: *Ext4Fs, allocator: Allocator, path: []const u8) !Entry {
        return self.navigator.getEntry(allocator, path);
    }

    pub fn extractFile(self: *Ext4Fs, entry: *const Entry) ![]u8 {
        return self.file_reader.readFile(entry);
    }

    pub fn listDirectory(self: *Ext4Fs, allocator: Allocator, entry: *const Entry) ![]Entry {
        return self.lister.listDirectory(allocator, entry);
    }
};
