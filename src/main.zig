const std = @import("std");
const ls = @import("fs-commads/ls.zig");
const cd = @import("fs-commads/cd.zig");

const c = @cImport({
    @cInclude("dirent.h");
    @cInclude("stdio.h");
    @cInclude("sys/stat.h");
    @cInclude("pwd.h");
    @cInclude("grp.h");
    @cInclude("time.h");
});

fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zigfs command [args]
        \\
        \\Commands:
        \\  ls Content list
        \\  cd [path] Change directory
    );
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    const command = args.next() orelse {
        try printUsage(stdout);
        return;
    };

    // commands handlers
    if (std.mem.eql(u8, command, "ls")) {
        try ls.run(allocator);
        return;
    }
    if (std.mem.eql(u8, command, "cd")) {
        const path = args.next();
        try cd.run(path);
        return;
    }

    try printUsage(stdout);
    std.debug.print("Error: Unknown command '{s}'\n", .{command});
    std.process.exit(1);
}
