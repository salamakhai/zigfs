const std = @import("std");

const Action = @import("action.zig").Action;
const Reader = std.io.AnyReader;
const Writer = std.io.AnyWriter;

pub const CoreError = error{
    UnknownAction,
    ActionFailed,
    InvalidArgument,
    OutOfMemory,
    WriteError,
    EndOfStream,
};

const DEFAULT_PROMPT = ">>> ";
const MAX_INPUT_LENGTH = 1024;

pub const Core = struct {
    pub const HELP_ACTION: []const u8 = "help";

    allocator: std.mem.Allocator,
    reader: Reader,
    writer: Writer,
    actions: []Action,

    pub fn init(
        allocator: std.mem.Allocator,
        reader: Reader,
        writer: Writer,
        actions: []Action,
    ) !*Core {
        const instance = try allocator.create(Core);
        instance.* = Core{
            .allocator = allocator,
            .reader = reader,
            .writer = writer,
            .actions = actions,
        };
        return instance;
    }

    pub fn deinit(self: *Core) void {
        self.allocator.destroy(self);
    }

    pub fn processArgs(self: *Core, args_iter: *std.process.ArgIterator) !void {
        _ = args_iter.skip();
        const action_name = args_iter.next() orelse Core.HELP_ACTION;

        var action_args = std.ArrayList([]const u8).init(self.allocator);
        defer action_args.deinit();

        while (args_iter.next()) |arg| {
            try action_args.append(arg);
        }

        try self.run(action_name, action_args.items);
    }

    pub fn run(self: *Core, action_name: []const u8, args: []const []const u8) !void {
        const action = self.findAction(action_name) orelse {
            try self.writer.print("Error: Unknown action '{s}'\n", .{action_name});
            return CoreError.UnknownAction;
        };

        try action.process(action, self, args, self.reader, self.writer);

        if (action.interactive) {
            try self.runInteractive(action);
        }
    }

    pub fn runInteractive(self: *Core, action: *Action) !void {
        try self.writer.print("\nType 'help' for available commands, 'exit' to quit.\n\n", .{});

        var running = true;
        while (running) {
            try self.writer.print(DEFAULT_PROMPT, .{});

            var input_buffer: [MAX_INPUT_LENGTH]u8 = undefined;
            const input = self.reader.readUntilDelimiter(&input_buffer, '\n') catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
            if (trimmed.len == 0) {
                continue;
            }

            var args_iter = std.mem.tokenizeAny(u8, trimmed, " \t");
            const sub_name = args_iter.next() orelse {
                continue;
            };

            if (std.mem.eql(u8, sub_name, "exit")) {
                running = false;
                continue;
            }

            if (std.mem.eql(u8, sub_name, "help")) {
                const help_target = args_iter.next();
                if (help_target) |target| {
                    if (action.findChild(target)) |child_action| {
                        // Create a mutable copy with parent set for context-dependent help
                        var mutable_child = child_action.*;
                        mutable_child.parent = action;
                        try mutable_child.printUsage(self.writer);
                    } else {
                        try self.writer.print("Unknown command: {s}\n", .{target});
                    }
                } else {
                    try action.printUsage(self.writer);
                }
                continue;
            }

            if (action.findChild(sub_name)) |child_action| {
                var child_args = std.ArrayList([]const u8).init(self.allocator);
                defer child_args.deinit();

                while (args_iter.next()) |arg| {
                    try child_args.append(arg);
                }

                // Create a mutable copy to inherit context and parent from parent action
                var mutable_child = child_action.*;
                mutable_child.context = action.context;
                mutable_child.parent = action;

                mutable_child.process(&mutable_child, self, child_args.items, self.reader, self.writer) catch |err| {
                    try self.writer.print("Error executing '{s}': {s}\n", .{ child_action.name, @errorName(err) });
                };
            } else {
                try self.writer.print("Unknown command: {s}. Type 'help' for available commands.\n", .{sub_name});
            }
        }
    }

    pub fn findAction(self: *const Core, name: []const u8) ?*Action {
        for (self.actions) |*action| {
            if (std.mem.eql(u8, action.name, name)) {
                return action;
            }
        }
        return null;
    }

    pub fn printActions(self: *Core) !void {
        try self.writer.print("Available actions:\n", .{});
        for (self.actions) |action| {
            try self.writer.print("  {s:<12} {s}\n", .{ action.name, action.description });
        }
        try self.writer.print("\n", .{});
    }

    // Utils
    pub fn prompt(self: *Core, text: []const u8) ![]u8 {
        try self.writer.print("{s}", .{text});

        var input_buffer: [MAX_INPUT_LENGTH]u8 = undefined;
        const input = try self.reader.readUntilDelimiter(&input_buffer, '\n');
        return std.mem.trim(u8, input, &std.ascii.whitespace);
    }

    pub fn confirm(self: *Core, question: []const u8) !bool {
        while (true) {
            const answer = self.prompt(
                []const u8("{s} (y/n): ", .{question}),
            );

            if (std.mem.eql(u8, answer, "y") or std.mem.eql(u8, answer, "Y") or std.mem.eql(u8, answer, "yes")) {
                return true;
            } else if (std.mem.eql(u8, answer, "n") or std.mem.eql(u8, answer, "N") or std.mem.eql(u8, answer, "no")) {
                return false;
            } else {
                try self.writer.print("Please answer y or n.\n", .{});
            }
        }
    }
};
