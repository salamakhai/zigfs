const std = @import("std");
const cli = @import("cli");

const CLI = cli.CLI;

pub const Runner = struct {
    runtimeCLI: *CLI,

    pub fn run(
        self: *Runner,
        registry: cli.Registry,
        allocator: std.mem.Allocator,
    ) !void {
        const writer = self.runtimeCLI.writer;

        var args_iter = try std.process.argsWithAllocator(allocator);
        defer args_iter.deinit();

        _ = args_iter.skip();

        const command_name = args_iter.next() orelse {
            try cli.printHelp(registry, writer);
            return;
        };

        if (std.mem.eql(u8, command_name, "help")) {
            const help_topic = args_iter.next();
            if (help_topic) |topic| {
                const found = try cli.printCmdHelp(registry, writer, topic);
                if (!found) {
                    try writer.print("Unknown command: '{s}'\n\n", .{topic});
                    try cli.printHelp(registry, writer);
                    std.process.exit(1);
                }
            } else {
                try cli.printHelp(registry, writer);
            }
            return;
        }

        if (registry.findCommand(command_name)) |cmd| {
            var command_args = std.ArrayList([]const u8).init(allocator);
            defer command_args.deinit();

            while (args_iter.next()) |arg| {
                try command_args.append(arg);
            }

            cmd.execute(allocator, command_args.items, writer) catch |err| {
                try writer.print("Error executing '{s}': {s}\n", .{ command_name, @errorName(err) });
                std.process.exit(1);
            };
            return;
        }

        try cli.printHelp(registry, writer);
        try writer.print("Error: Unknown command '{s}'\n", .{command_name});
        std.process.exit(1);
    }
};
