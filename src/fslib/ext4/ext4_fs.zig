const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Reader = @import("operations/reader.zig").Reader;
const PathResolver = @import("operations/path_resolver.zig").PathResolver;
const DirectoryReader = @import("operations/directory_reader.zig").DirectoryReader;
const FileOperations = @import("operations/file_operations.zig").FileOperations;

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
    path_resolver: PathResolver,
    directory_reader: DirectoryReader,
    file_operations: FileOperations,

    // Lifecycle
    pub fn detect(file: fs.File) bool {
        return Superblock.detect(file);
    }

    pub fn create(allocator: Allocator, file: fs.File, filename: []const u8) !*Ext4 {
        const superblock = try Superblock.create(file);
        const filesystem = try allocator.create(Ext4);

        // TODO -- Temp solution: in the future get volume name from superblock instead
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
            .path_resolver = undefined,
            .directory_reader = undefined,
            .file_operations = undefined,
        };

        filesystem.reader = Reader.init(allocator, file, &filesystem.superblock);
        filesystem.path_resolver = PathResolver.init(&filesystem.reader);
        filesystem.directory_reader = DirectoryReader.init(&filesystem.reader);
        filesystem.file_operations = FileOperations.init(&filesystem.reader);

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
        return self.path_resolver.getRootEntry();
    }

    pub fn getEntry(self: *Ext4, allocator: Allocator, path: []const u8) !Entry {
        return self.path_resolver.resolvePath(allocator, path);
    }

    pub fn extractFile(self: *Ext4, entry: *const Entry) ![]u8 {
        return self.file_operations.readContent(entry);
    }

    pub fn listDirectory(self: *Ext4, allocator: Allocator, entry: *const Entry) ![]Entry {
        return self.directory_reader.readDirectory(allocator, entry);
    }
};
