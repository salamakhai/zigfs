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

pub fn printFileInfo(allocator: std.mem.Allocator, entry: *c.dirent, writer: anytype) !void {
    var stat_buf: c.struct_stat = undefined;
    const name = std.mem.sliceTo(&entry.d_name, 0);

    const full_path = try std.fs.path.join(allocator, &[_][]const u8{ ".", name });
    defer allocator.free(full_path);

    if (c.stat(full_path.ptr, &stat_buf) == 0) {
        const mode = try formatMode(stat_buf.st_mode);
        const pw = c.getpwuid(stat_buf.st_uid);
        const gr = c.getgrgid(stat_buf.st_gid);

        try writer.print(
            "{s} {d: >3} {s: <8} {s: <8} {d: >8} {s}\n",
            .{ //
                mode, //
                stat_buf.st_nlink, //
                if (pw) |p| std.mem.span(p.*.pw_name) else "unknown", //
                if (gr) |g| std.mem.span(g.*.gr_name) else "unknown", //
                stat_buf.st_size, //
                name, //
            },
        );
    }
}

// helpers
fn formatMode(mode: c_uint) ![10:0]u8 {
    var result = [_:0]u8{'-'} ** 10;

    if ((mode & c.S_IFDIR) != 0) result[0] = 'd';
    if ((mode & c.S_IRUSR) != 0) result[1] = 'r';
    if ((mode & c.S_IWUSR) != 0) result[2] = 'w';
    if ((mode & c.S_IXUSR) != 0) result[3] = 'x';
    if ((mode & c.S_IRGRP) != 0) result[4] = 'r';
    if ((mode & c.S_IWGRP) != 0) result[5] = 'w';
    if ((mode & c.S_IXGRP) != 0) result[6] = 'x';
    if ((mode & c.S_IROTH) != 0) result[7] = 'r';
    if ((mode & c.S_IWOTH) != 0) result[8] = 'w';
    if ((mode & c.S_IXOTH) != 0) result[9] = 'x';

    return result;
}
