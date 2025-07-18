const Core = @import("../core/core.zig").Core;
const Allocator = Core.Allocator;

const fslib = @import("fslib");
const fs_session = @import("session.zig");

pub const FilesystemContext = struct {
    // Types
    pub const Filesystem = fslib.FileSystem;
    const Session = fs_session.FilesystemSession;

    // Fields
    filesystem: *Filesystem,
    session: Session,
    allocator: Allocator,

    // Lifecycle
    pub fn init(allocator: Allocator, fs: *Filesystem) !FilesystemContext {
        const session = try Session.init(allocator);

        return FilesystemContext{
            .filesystem = fs,
            .session = session,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FilesystemContext) void {
        self.session.deinit();
        self.filesystem.deinit();
        self.allocator.destroy(self.filesystem);
    }
};
