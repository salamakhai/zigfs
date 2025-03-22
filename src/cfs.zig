const std = @import("std");

const c = @cImport({
    @cInclude("dirent.h");
    @cInclude("stdio.h");
    @cInclude("sys/stat.h");
    @cInclude("pwd.h");
    @cInclude("grp.h");
    @cInclude("time.h");
});

const DirError = error{ DirOpenFailed, DirCloseFailed, AllocationFailed, OutOfMemory };

pub fn openDir(path: []const u8) DirError!?*c.DIR {
    const dir = c.opendir(@ptrCast(path.ptr));
    if (dir == null) {
        std.debug.print("Error opening directory: {s}\n", .{path});
        return DirError.DirOpenFailed;
    }
    return dir;
}

pub fn closeDir(dir: *c.DIR) DirError!void {
    if (c.closedir(dir) != 0) {
        return DirError.DirCloseFailed;
    }
    return;
}

pub fn readDir(allocator: std.mem.Allocator, dir: *c.DIR) DirError![]*c.dirent {
    var entries = std.ArrayList(*c.dirent).init(allocator);

    while (true) {
        const entry = c.readdir(dir);
        if (entry == null) break;

        try entries.append(entry);
    }

    return entries.toOwnedSlice();
}
