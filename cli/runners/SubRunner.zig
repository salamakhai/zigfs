const std = @import("std");
const cli = @import("cli");

const Reader = cli.Reader;
const Writer = cli.Writer;
const Command = cli.Command;
const Registry = cli.Registry;
const Error = cli.CliError;

const MAX_HISTORY_SIZE = 100;
const DEFAULT_PROMPT = ">>> ";
const MAX_INPUT_LENGTH = 1024;

pub const SubRunner = struct {
    //
    /// Context and history for the runner session
    pub const State = struct {
        allocator: std.mem.Allocator,
        context_name: []const u8,
        history: std.ArrayList([]const u8),
        history_index: usize,

        context_data: ?*anyopaque,
        wait_exit: bool,

        //
        // LIFECYCLE
        //
        pub fn init(allocator: std.mem.Allocator, context_name: []const u8) !State {
            const name_dup = try allocator.dupe(u8, context_name);

            return State{
                .allocator = allocator,
                .context_name = name_dup,
                .history = std.ArrayList([]const u8).init(allocator),
                .history_index = 0,
                .context_data = null,
                .wait_exit = false,
            };
        }

        pub fn deinit(self: *State) void {
            for (self.history.items) |entry| {
                self.allocator.free(entry);
            }
            self.history.deinit();
            self.allocator.free(self.context_name);
        }

        //
        // HISTORY
        //
        pub fn addHistoryItem(self: *State, command: []const u8) !void {
            if (command.len == 0) {
                return;
            }

            const command_dup = try self.allocator.dupe(u8, command);
            errdefer self.allocator.free(command_dup);

            if (self.history.items.len >= MAX_HISTORY_SIZE) {
                const oldest = self.history.orderedRemove(0);
                self.allocator.free(oldest);
            }
            try self.history.append(command_dup);
            self.history_index = self.history.items.len;
        }

        pub fn previousHistoryItem(self: *State) ?[]const u8 {
            if (self.history.items.len == 0) {
                return null;
            }
            if (self.history_index > 0) {
                self.history_index -= 1;
            }

            return self.history.items[self.history_index];
        }

        pub fn nextHistoryItem(self: *State) ?[]const u8 {
            if (self.history.items.len == 0 or self.history_index >= self.history.items.len) {
                return null;
            }

            if (self.history_index < self.history.items.len - 1) {
                self.history_index += 1;
                return self.history.items[self.history_index];
            } else {
                self.history_index = self.history.items.len;
                return "";
            }
        }

        //
        // CONTEXT
        //
        pub fn setContextData(self: *State, data: *anyopaque) void {
            self.context_data = data;
        }

        pub fn getContextData(self: *State) ?*anyopaque {
            return self.context_data;
        }

        pub fn exit(self: *State) void {
            self.wait_exit = true;
        }
    };

    //
    // PROCESS
    //
    pub fn run(
        reader: Reader,
        writer: Writer,
        registry: *const Registry,
        allocator: std.mem.Allocator,
        state: *State,
    ) !void {
        try writer.print("\n {s} interactive mode.\n", .{state.context_name});
        try writer.print("Type 'help' for available commands, 'exit' to quit.\n\n", .{});

        while (!state.wait_exit) {
            try writer.print(DEFAULT_PROMPT, .{});

            // read input
            var input_buffer: [MAX_INPUT_LENGTH]u8 = undefined;
            const input = reader.readUntilDelimiterOrEof(&input_buffer, '\n') catch |err| {
                try writer.print("Error reading input: {s}\n", .{@errorName(err)});
                continue;
            } orelse {
                state.exit();
                break;
            };

            const trimmed_input = std.mem.trim(u8, input, &std.ascii.whitespace);
            if (trimmed_input.len == 0) {
                continue;
            }

            try state.addHistoryItem(trimmed_input);

            var args_iter = std.mem.tokenize(u8, trimmed_input, " \t");
            const command_name = args_iter.next() orelse continue;

            if (handleBuiltInCommand(command_name, &args_iter, registry, writer, state)) {
                continue;
            }

            try handleRegistryCommand(registry, command_name, &args_iter, allocator, writer);
        }

        try writer.print("Exiting {s} mode.\n", .{state.context_name});
    }

    //
    // PRIVATE
    //
    fn handleBuiltInCommand(
        command_name: []const u8,
        args_iter: *std.mem.TokenIterator(u8, .any),
        registry: *const Registry,
        stdout: Writer,
        state: *State,
    ) bool {
        if (std.mem.eql(u8, command_name, "exit")) {
            state.exit();
            return true;
        } else if (std.mem.eql(u8, command_name, "clear")) {
            // ANSI escape sequence to clear screen and reset cursor position
            stdout.print("\x1B[2J\x1B[H", .{}) catch {};
            return true;
        } else if (std.mem.eql(u8, command_name, "help")) {
            const help_topic = args_iter.next();
            if (help_topic) |topic| {
                if (registry.findCommand(topic)) |cmd| {
                    // Display help for specific command
                    stdout.print("\n{s}\n\n", .{cmd.help}) catch {};
                } else {
                    stdout.print("Unknown command: '{s}'\n", .{topic}) catch {};
                }
            } else {
                // Display general help
                stdout.print("\nAvailable commands in {s} mode:\n\n", .{state.context_name}) catch {};

                // Built-in commands
                stdout.print("  help    - Display this help message\n", .{}) catch {};
                stdout.print("  clear   - Clear the screen\n", .{}) catch {};
                stdout.print("  exit    - Exit {s} mode\n\n", .{state.context_name}) catch {};

                // Registry commands
                for (registry.commands) |cmd| {
                    stdout.print("  {s:<8} - {s}\n", .{ cmd.name, cmd.description }) catch {};
                }
                stdout.print("\nUse 'help <command>' for detailed help on a specific command.\n\n", .{}) catch {};
            }
            return true;
        }

        return false;
    }

    fn handleRegistryCommand(
        registry: *const Registry,
        command_name: []const u8,
        args_iter: *std.mem.TokenIterator(u8, .any),
        allocator: std.mem.Allocator,
        stdout: Writer,
    ) !void {
        if (registry.findCommand(command_name)) |cmd| {
            var args = std.ArrayList([]const u8).init(allocator);
            defer args.deinit();

            while (args_iter.next()) |arg| {
                try args.append(arg);
            }

            cmd.function(allocator, args.items, stdout) catch |err| {
                try stdout.print(
                    "Error executing '{s}': {s}\n",
                    .{ command_name, @errorName(err) },
                );
            };
        } else {
            try stdout.print("Unknown command: '{s}'\n", .{command_name});
        }
    }
};
