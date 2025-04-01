const std = @import("std");

pub fn list_directory() !void {
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        std.debug.print("{s}\n", .{entry.name});
    }
}
