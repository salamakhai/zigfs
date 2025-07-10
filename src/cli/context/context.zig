const std = @import("std");
const Core = @import("../core/core.zig").Core;
const Allocator = Core.Allocator;

/// Unified context
pub const Context = struct {
    filesystem: ?FilesystemContext = null,

    // Types
    pub const FilesystemContext = @import("context_filesystem.zig").FilesystemContext;
    const FileSystem = FilesystemContext.Filesystem;

    // Lifecycle
    pub fn init() Context {
        return Context{};
    }

    pub fn deinit(self: *Context) void {
        if (self.filesystem) |*fs| fs.deinit();
    }

    // FileSystem
    pub fn newFilesystem(self: *Context, allocator: Allocator, fs: *FileSystem) !void {
        if (self.filesystem) |*current| {
            current.deinit();
        }

        self.filesystem = try FilesystemContext.init(allocator, fs);
    }
};
