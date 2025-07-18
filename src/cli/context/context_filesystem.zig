const Core = @import("../core/core.zig").Core;
const Allocator = Core.Allocator;

pub const FilesystemContext = struct {
    // Variables
    filesystem: *Filesystem,
    session: Session,
    allocator: Allocator,

    // Types
    pub const Filesystem = @import("fslib").FileSystem;
    const Session = @import("filesystem_session.zig").FilesystemSession;

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
