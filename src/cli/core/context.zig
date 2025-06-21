const std = @import("std");
const Core = @import("core.zig").Core;
const Allocator = Core.Allocator;

const fslib = @import("fslib");
const FileSystem = fslib.FileSystem;

/// Unified context
pub const Context = struct {
    filesystem: ?FileSystemContext = null,

    // Lifecycle
    pub fn init() Context {
        return Context{};
    }

    pub fn deinit(self: *Context) void {
        if (self.filesystem) |*fs| fs.deinit();
    }

    // FileSystem
    pub fn setFileSystem(self: *Context, allocator: Allocator, fs: *FileSystem) void {
        if (self.filesystem) |*current| {
            current.deinit();
        }

        self.filesystem = FileSystemContext.init(allocator, fs);
    }

    pub fn getFileSystem(self: *const Context) ?*FileSystem {
        if (self.filesystem) |*fs| return fs.getCtx();
        return null;
    }
};

const FileSystemContext = struct {
    filesystem: *FileSystem,
    allocator: Allocator,

    pub fn init(allocator: Allocator, fs: *FileSystem) FileSystemContext {
        return FileSystemContext{
            .filesystem = fs,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FileSystemContext) void {
        self.filesystem.deinit();
        self.allocator.destroy(self.filesystem);
    }

    pub fn getCtx(self: *const FileSystemContext) ?*FileSystem {
        return self.filesystem;
    }
};
