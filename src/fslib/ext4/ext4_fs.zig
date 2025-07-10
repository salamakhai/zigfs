const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Reader = @import("operations/reader.zig").Reader;
const Navigator = @import("operations/navigator.zig").Navigator;
const EntryTraversal = @import("operations/entry_traversal.zig").EntryTraversal;
const FileReader = @import("operations/file_reader.zig").FileReader;

pub const Ext4 = struct {
    // Types
    pub const Superblock = @import("structures/superblock.zig").Superblock;
    pub const Entry = @import("structures/entry.zig").Entry;
    pub const Inode = @import("structures/inode.zig").Inode;
    pub const Error = @import("ext4_error.zig").Ext4Error;

    // Vaiables
    file: fs.File,
    allocator: Allocator,
    filename: []u8,

    // structures
    superblock: Superblock,

    // operations
    reader: Reader,
    navigator: Navigator,
    traversal: EntryTraversal,
    file_reader: FileReader,

    // Lifecycle
    pub fn detect(file: fs.File) bool {
        return Superblock.detect(file);
    }

    pub fn create(allocator: Allocator, file: fs.File, filename: []const u8) !*Ext4 {
        const superblock = try Superblock.create(file);
        const filesystem = try allocator.create(Ext4);

        // TODO -- Temp solution: in the future get volume name in superblock instead
        const basename = std.fs.path.basename(filename);
        const formatted_name = if (std.mem.lastIndexOf(u8, basename, ".")) |dot_index|
            basename[0..dot_index]
        else
            basename;

        filesystem.* = Ext4{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
            .filename = try allocator.dupe(u8, formatted_name),
            .reader = undefined,
            .navigator = undefined,
            .traversal = undefined,
            .file_reader = undefined,
        };

        filesystem.reader = Reader.init(allocator, file, &filesystem.superblock);
        filesystem.navigator = Navigator.init(&filesystem.reader);
        filesystem.traversal = EntryTraversal.init(&filesystem.reader);
        filesystem.file_reader = FileReader.init(&filesystem.reader);

        return filesystem;
    }

    pub fn destroy(self: *Ext4) void {
        self.file.close();
        self.allocator.free(self.filename);
        self.allocator.destroy(self);
    }

    // Public
    pub fn getOwnedFileName(self: *Ext4) []const u8 {
        return self.filename;
    }

    pub fn getRootEntry(self: *Ext4) !Entry {
        return self.navigator.getRootEntry();
    }

    pub fn getEntry(self: *Ext4, allocator: Allocator, path: []const u8) !Entry {
        return self.navigator.getEntry(allocator, path);
    }

    pub fn extractFile(self: *Ext4, entry: *const Entry) ![]u8 {
        return self.file_reader.readFile(entry);
    }

    pub fn listDirectory(self: *Ext4, allocator: Allocator, entry: *const Entry) ![]Entry {
        return self.traversal.listDirectory(allocator, entry);
    }
};
