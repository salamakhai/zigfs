const std = @import("std");
const cli = @import("cli");

const Reader = cli.Reader;
const Writer = cli.Writer;

pub const CoreError = error{
    UnknownCommand,
    CommandFailed,
    InvalidArgument,
    OutOfMemory,
    WriteError,
};

pub const Core = struct {
    allocator: std.mem.Allocator,
    reader: Reader,
    writer: Writer,

    // Variables
    commands: []const cli.Command,
    initialized: bool = false,

    runner: cli.Runner,

    //
    // ---LIFECYCLE---
    //
    pub fn init(
        allocator: std.mem.Allocator,
        reader: Reader,
        writer: Writer,
        commands: []const cli.Command,
    ) !*Core {
        var instance = try allocator.create(Core);
        instance.* = Core{
            .allocator = allocator,
            .reader = reader,
            .writer = writer,
            .commands = commands,
            .initialized = true,
            .runner = undefined, // Will be set below
        };

        instance.runner = cli.Runner{
            .core = instance,
            .initialized = true,
        };
        return instance;
    }

    pub fn deinit(self: *Core) void {
        // No need to call runner.deinit() as it's an inline struct
        self.allocator.destroy(self);
    }

    //
    // ---PUBLIC---
    //
    pub fn processArgs(
        self: *Core,
        args_iter: *std.process.ArgIterator,
    ) anyerror!void {
        const allocator = self.allocator;
        const writer = self.writer;
        const registry = self.commands;

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

        if (self.findCommand(command_name)) |cmd| {
            var command_args = std.ArrayList([]const u8).init(allocator);
            defer command_args.deinit();

            while (args_iter.next()) |arg| {
                try command_args.append(arg);
            }

            self.runner.run(
                cmd,
                command_args.items,
            ) catch |err| {
                try writer.print("\nRunner errror: {s}\n", .{@errorName(err)});
                std.process.exit(1);
            };
            return;
        }

        try cli.printHelp(registry, writer);
        try writer.print("Error: Unknown command '{s}'\n", .{command_name});
        std.process.exit(1);
    }

    //
    // ---PRIVATE---
    //
    fn findCommand(self: *const Core, name: []const u8) ?*const cli.Command {
        for (self.commands) |*command| {
            if (std.mem.eql(u8, command.name, name)) {
                return command;
            }
        }
        return null;
    }

    // fn signalHandlers(self: *const Core) !void {
    //     // Handlers for SIGINT, SIGTERM, etc.
    // }

    // fn handleShutdown(self: *const Core) void {
    //     // Cleanup
    //     std.debug.print("Shutting down...\n", .{});
    // }
};
