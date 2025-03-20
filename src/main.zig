const std = @import("std");
const fs = @import("c_fs");

const c = @cImport({
    @cInclude("dirent.h");
    @cInclude("stdio.h");
    @cInclude("sys/stat.h");
    @cInclude("pwd.h");
    @cInclude("grp.h");
    @cInclude("time.h");
});

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    const dir = (try fs.openDir("./")) orelse return error.DirOpenFailed;
    defer {
        fs.closeDir(dir) catch {
            std.debug.print("Error closing directory\n", .{});
        };
    }

    const entries = try fs.readDir(allocator, dir);
    defer allocator.free(entries);

    for (entries) |entry| {
        try fs.printFileInfo(allocator, entry, stdout);
    }
}
