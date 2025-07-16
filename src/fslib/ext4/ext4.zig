const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const DiskReader = @import("disk/reader.zig").Reader;
const Resolver = @import("operations/resolver.zig").Resolver;
const Walker = @import("operations/walker.zig").Walker;
const FileReader = @import("operations/reader.zig").Reader;

pub const Ext4 = struct {
    // Types
    pub const Superblock = @import("types/superblock.zig").Superblock;
    pub const Entry = @import("types/entry.zig").Entry;
    pub const Inode = @import("types/inode.zig").Inode;
    pub const Error = @import("error.zig").Ext4Error;

    // Fields
    file: fs.File,
    allocator: Allocator,
    filename: []u8,

    // structures
    superblock: Superblock,

    // parsing
    disk_reader: DiskReader,
    resolver: Resolver,
    walker: Walker,
    file_reader: FileReader,

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
            .disk_reader = undefined,
            .resolver = undefined,
            .walker = undefined,
            .file_reader = undefined,
        };

        filesystem.disk_reader = DiskReader.init(allocator, file, filesystem.superblock.blockSize());
        filesystem.resolver = Resolver.init(&filesystem.disk_reader, &filesystem.superblock);
        filesystem.walker = Walker.init(&filesystem.disk_reader, &filesystem.superblock);
        filesystem.file_reader = FileReader.init(&filesystem.disk_reader, &filesystem.superblock);

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
        return self.resolver.getRootEntry();
    }

    pub fn getEntry(self: *Ext4, allocator: Allocator, path: []const u8) !Entry {
        return self.resolver.resolvePath(allocator, path);
    }

    pub fn extractFile(self: *Ext4, entry: *const Entry) ![]u8 {
        return self.file_reader.readContent(entry);
    }

    pub fn listDirectory(self: *Ext4, allocator: Allocator, entry: *const Entry) ![]Entry {
        return self.walker.readDirectory(allocator, entry);
    }
};
