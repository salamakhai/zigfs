const std = @import("std");
const cli = @import("cli");

const Core = cli.Core;

const Reader = cli.Reader;
const Writer = cli.Writer;
const Command = cli.Command;

const DEFAULT_PROMPT = ">>> ";
const MAX_INPUT_LENGTH = 1024;

pub const RunnerError = error{
    InitFail,
    DeinitFail,
    CommandNotFound,
};

pub const Runner = struct {
    core: *const Core,

    // Variables
    initialized: bool = false,

    //
    // LIFECYCLE
    //
    pub fn init(
        core: *const Core,
    ) RunnerError!*Runner {
        const allocator = core.allocator;
        var instance = try allocator.create(Runner);

        instance.* = Runner{
            .core = core,
        };
        instance.initialized = true;

        return instance;
    }

    pub fn deinit(self: *Runner) RunnerError!void {
        self.core.allocator.destroy(self);
    }

    //
    // PROCESS
    //
    pub fn run(
        self: *Runner,
        command: *const Command,
        args: []const []const u8,
    ) anyerror!void {
        const reader = self.core.reader;
        const writer = self.core.writer;

        if (!try command.isInteractive()) {
            // once
            command.process(
                self,
                args,
                reader,
                writer,
            ) catch |err| {
                try writer.print("\nError executing command '{s}': {s}\n", .{ command.name, @errorName(err) });
            };
        } else {
            // loop
            try writer.print("\n Entered iteractive mode.\n", .{});
            try writer.print("Type 'help' for available commands, 'exit' to quit.\n\n", .{});

            var isRunning = true;

            while (isRunning) {
                try writer.print(DEFAULT_PROMPT, .{});

                // read input
                var input_buffer: [MAX_INPUT_LENGTH]u8 = undefined;
                const input = reader.readUntilDelimiterOrEof(&input_buffer, '\n') catch |err| {
                    try writer.print("Error reading input: {s}\n", .{@errorName(err)});
                    continue;
                } orelse {
                    isRunning = false;
                    break;
                };

                const trimmed_input = std.mem.trim(u8, input, &std.ascii.whitespace);
                if (trimmed_input.len == 0) {
                    continue;
                }
                // TODO: append state history

                var args_iter = std.mem.tokenizeAny(u8, trimmed_input, " \t");
                const command_name = args_iter.next() orelse {
                    continue;
                };

                if (std.mem.eql(u8, command_name, "exit")) {
                    isRunning = false;
                    continue;
                }

                if (command.findSubCommand(command_name)) |subCommand| {
                    subCommand.process(
                        command,
                        args,
                        reader,
                        writer,
                    ) catch |err| {
                        try writer.print("\nError executing sub-command '{s}': {s}\n", .{ subCommand.name, @errorName(err) });
                    };
                    continue;
                }
            }

            try writer.print("Exiting interactive mode.\n", .{});
        }
    }

    //
    // PRIVATE
    //
};
