const std = @import("std");
const Core = @import("core.zig").Core;
const Allocator = Core.Allocator;

const fslib = @import("fslib");
const FileSystem = fslib.FileSystem;

pub const Context = struct {
    filesystem: ?*FileSystem = null,
    allocator: ?Allocator = null,

    // Lifecycle
    pub fn init() Context {
        return Context{};
    }

    pub fn deinit(self: *Context) void {
        self.clearFileSystem();
        self.allocator = null;
    }

    // FileSystem
    pub fn setFileSystem(self: *Context, allocator: Allocator, fs: *FileSystem) void {
        self.clearFileSystem();

        self.filesystem = fs;
        self.allocator = allocator;
    }

    pub fn getFileSystem(self: *const Context) ?*FileSystem {
        return self.filesystem;
    }

    pub fn clearFileSystem(self: *Context) void {
        if (self.filesystem) |fs| {
            if (self.allocator) |alloc| {
                fs.deinit();
                alloc.destroy(fs);
            }
        }
        self.filesystem = null;
    }
};
