const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Filesystem = struct {
    // Variables
    filesystem: Union,
    mounted_type: Type,

    // Types
    pub const Ext4 = @import("ext4/ext4_fs.zig").Ext4;
    pub const Type = enum {
        ext4,
    };
    const Union = union(Type) {
        ext4: *Ext4,
    };

    // Lifecycle
    pub fn create(allocator: Allocator, file: std.fs.File, filename: []const u8) !Filesystem {
        if (Ext4.detect(file)) {
            const ext4_fs = try Ext4.create(allocator, file, filename);
            return Filesystem{
                .filesystem = Union{ .ext4 = ext4_fs },
                .mounted_type = .ext4,
            };
        }

        return error.UnsupportedFilesystem;
    }

    pub fn destroy(self: *Filesystem) void {
        switch (self.filesystem) {
            .ext4 => |fs| fs.destroy(),
        }
    }

    // Public
    pub fn resolve(self: *const Filesystem) Type {
        return self.mounted_type;
    }

    pub fn get(self: *const Filesystem, comptime T: type) !*T {
        switch (T) {
            Ext4 => {
                switch (self.filesystem) {
                    .ext4 => |fs| return fs,
                }
            },
            else => return error.UnsupportedFilesystem,
        }
    }

    pub fn getOwnedName(self: *const Filesystem) []const u8 {
        const ext4_fs = self.get(Ext4) catch return "unknown";
        return ext4_fs.getOwnedFileName();
    }
};