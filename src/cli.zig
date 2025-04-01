const std = @import("std");
const ls = @import("fs-commands/ls.zig");

pub fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zigfs command [args]
        \\
        \\Commands:
        \\  ls         - List directory contents
        \\  cd [path]  - Change directory (defaults to current dir if no path)
        \\  pwd        - Print current working directory
        \\
    );
}

pub fn handleArgs(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // Skip program name

    const command = args.next() orelse {
        try printUsage(stdout);
        return;
    };

    if (std.mem.eql(u8, command, "ls")) {
        try ls.list_directory();
        return;
    }

    try printUsage(stdout);
    try stdout.print("Error: Unknown command '{s}'\n", .{command});
    std.process.exit(1);
}
