const std = @import("std");
const cfs = @import("c_fs");

pub fn run(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const dir = (try cfs.openDir("./")) orelse return error.DirOpenFailed;
    defer {
        cfs.closeDir(dir) catch {
            std.debug.print("Error closing directory\n", .{});
        };
    }

    const entries = try cfs.readDir(allocator, dir);
    defer allocator.free(entries);

    for (entries) |entry| {
        try cfs.printFileInfo(allocator, entry, stdout);
    }
}
