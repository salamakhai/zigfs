const std = @import("std");
const Allocator = std.mem.Allocator;

pub const FilesystemSession = struct {
    // Fields
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
        self.current_dir = try normilizePath(self.allocator, current_dir);
    }

    pub fn getCurrentDirectory(self: *const FilesystemSession) []const u8 {
        return self.current_dir;
    }

    pub fn buildCurrentPath(self: *const FilesystemSession, allocator: Allocator, path: []const u8) ![]u8 {
        const current_dir = self.getCurrentDirectory();
        if (std.mem.startsWith(u8, path, "/")) {
            return try allocator.dupe(u8, path);
        } else {
            return try std.fs.path.join(allocator, &[_][]const u8{ current_dir, path });
        }
    }

    // Private
    fn normilizePath(allocator: Allocator, path: []const u8) ![]u8 {
        var components = std.ArrayList([]const u8).init(allocator);
        defer components.deinit();

        // Check special entries
        var iter = std.mem.splitScalar(u8, path, '/');
        while (iter.next()) |part| {
            if (part.len == 0 or std.mem.eql(u8, part, ".")) {
                continue;
            } else if (std.mem.eql(u8, part, "..")) {
                // Go up one level
                if (components.items.len > 0) {
                    _ = components.pop();
                }
            } else {
                try components.append(part);
            }
        }

        if (components.items.len == 0) {
            return try allocator.dupe(u8, "/");
        }

        var result = std.ArrayList([]const u8).init(allocator);
        defer result.deinit();

        try result.append("");
        for (components.items) |part| {
            try result.append(part);
        }

        return try std.mem.join(allocator, "/", result.items);
    }
};
