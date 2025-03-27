const std = @import("std");

const c = @cImport({
    @cInclude("dirent.h");
    @cInclude("stdio.h");
    @cInclude("sys/stat.h");
    @cInclude("pwd.h");
    @cInclude("grp.h");
    @cInclude("time.h");
});

const Error = error{ DirOpenFailed, DirCloseFailed, AllocationFailed, OutOfMemory };

pub fn openDir(path: []const u8) Error!?*c.DIR {
    const dir = c.opendir(@ptrCast(path.ptr));
    if (dir == null) {
        std.debug.print("Error opening directory: {s}\n", .{path});
        return Error.DirOpenFailed;
    }
    return dir;
}

pub fn closeDir(dir: *c.DIR) Error!void {
    if (c.closedir(dir) != 0) {
        return Error.DirCloseFailed;
    }
    return;
}

pub fn readDir(allocator: std.mem.Allocator, dir: *c.DIR) Error![]*c.dirent {
    var entries = std.ArrayList(*c.dirent).init(allocator);

    while (true) {
        const entry = c.readdir(dir);
        if (entry == null) break;

        try entries.append(entry);
    }

    return entries.toOwnedSlice();
}
