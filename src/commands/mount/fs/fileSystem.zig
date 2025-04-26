const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Superblock = @import("Superblock.zig").Superblock;

pub const FileSystemError = error{
    ReadError,
    OutOfBounds,
    InvalidMagicNumber,
    NotExt4Format,
    InvalidBlockSize,
};

pub const FileSystem = struct {
    file: fs.File,
    superblock: Superblock,
    allocator: Allocator,
    block_size: u32,

    pub fn init(
        allocator: Allocator,
        file: fs.File,
    ) !*FileSystem {
        var superblock = try Superblock.fromFile(file);

        const image = try allocator.create(FileSystem);
        image.* = FileSystem{
            .file = file,
            .superblock = superblock,
            .allocator = allocator,
            .block_size = superblock.blockSize(),
        };

        return image;
    }

    pub fn deinit(self: *FileSystem) void {
        self.file.close();
        self.allocator.destroy(self);
    }
};
