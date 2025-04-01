const std = @import("std");

const ls = @import("fs-commands/ls.zig");
const cd = @import("fs-commands/cd.zig");

pub fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zigfs command [args]
        \\
        \\Commands:
        \\  ls         - List directory contents
        \\  cls        - Clear terminal screen
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
    // if (std.mem.eql(u8, command, "cd")) {
    //     const path = args.next() orelse ".";
    //     try cd.change_directory(path);
    //     return;
    // }

    try printUsage(stdout);
    try stdout.print("Error: Unknown command '{s}'\n", .{command});
    std.process.exit(1);
}
