const std = @import("std");
const Allocator = std.mem.Allocator;

pub const FilesystemSession = struct {
    // Variables
    allocator: Allocator,
    current_dir: []u8,

    // Lifecycle
    pub fn init(allocator: Allocator) !FilesystemSession {
        const current_dir = try allocator.dupe(u8, "/");
        return FilesystemSession{
            .allocator = allocator,
            .current_dir = current_dir,
        };
    }

    pub fn deinit(self: *FilesystemSession) void {
        self.allocator.free(self.current_dir);
    }

    // Public
    pub fn setCurrentDirectory(self: *FilesystemSession, current_dir: []const u8) !void {
        self.allocator.free(self.current_dir);
        self.current_dir = try self.allocator.dupe(u8, current_dir);
    }

    pub fn getCurrentDirectory(self: *const FilesystemSession) []const u8 {
        return self.current_dir;
    }

    pub fn buildCurrentPath(self: *const FilesystemSession, allocator: Allocator, path: []const u8) ![]const u8 {
        const current_dir = self.getCurrentDirectory();
        if (std.mem.startsWith(u8, path, "/")) {
            return try allocator.dupe(u8, path);
        } else {
            return try std.fs.path.join(allocator, &[_][]const u8{ current_dir, path });
        }
    }
};
