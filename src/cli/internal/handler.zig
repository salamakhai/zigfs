const std = @import("std");
const types = @import("cli_types");
const help = @import("help.zig");

/// Main function to handle command line arguments
pub fn handleArgs(registry: types.cmd.Registry, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.skip();

    const command_name = args_iter.next() orelse {
        try help.printUsage(registry, stdout);
        return;
    };

    if (std.mem.eql(u8, command_name, "help")) {
        const help_topic = args_iter.next();
        if (help_topic) |topic| {
            const found = try help.printCommandHelp(registry, stdout, topic);
            if (!found) {
                try stdout.print("Unknown command: '{s}'\n\n", .{topic});
                try help.printUsage(registry, stdout);
                std.process.exit(1);
            }
        } else {
            try help.printUsage(registry, stdout);
        }
        return;
    }

    if (registry.findCommand(command_name)) |cmd| {
        var command_args = std.ArrayList([]const u8).init(allocator);
        defer command_args.deinit();

        while (args_iter.next()) |arg| {
            try command_args.append(arg);
        }

        cmd.execute(allocator, command_args.items, stdout) catch |err| {
            try stdout.print("Error executing '{s}': {s}\n", .{ command_name, @errorName(err) });
            std.process.exit(1);
        };
        return;
    }

    try help.printUsage(registry, stdout);
    try stdout.print("Error: Unknown command '{s}'\n", .{command_name});
    std.process.exit(1);
}
