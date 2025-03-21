const std = @import("std");
const ls = @import("cmd_ls.zig");

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
        \\  ls  Content list
        \\
        \\
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

    if (std.mem.eql(u8, command, "ls")) {
        try ls.run(allocator);
        return;
    }

    try printUsage(stdout);
    std.debug.print("Error: Unknown command '{s}'\n", .{command});
    std.process.exit(1);
}
