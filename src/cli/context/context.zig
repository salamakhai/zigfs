const std = @import("std");
const Core = @import("../core/core.zig").Core;
const Allocator = Core.Allocator;

const context_filesystem = @import("fs/context.zig");

/// Unified context
pub const Context = struct {
    // Types
    pub const FilesystemContext = context_filesystem.FilesystemContext;
    const FileSystem = FilesystemContext.Filesystem;

    // Fields
    filesystem: ?FilesystemContext = null,

    // Lifecycle
    pub fn init() Context {
        return Context{};
    }

    pub fn deinit(self: *Context) void {
        if (self.filesystem) |*fs| fs.deinit();
    }

    // FileSystem
    pub fn initFilesystem(self: *Context, allocator: Allocator, fs: *FileSystem) !void {
        if (self.filesystem) |*current| {
            current.deinit();
        }

        self.filesystem = try FilesystemContext.init(allocator, fs);
    }
};
