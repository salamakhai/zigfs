const std = @import("std");

pub const Core = struct {
    // Types
    pub const Allocator = std.mem.Allocator;
    pub const Reader = std.io.AnyReader;
    pub const Writer = std.io.AnyWriter;
    pub const ArgIterator = @import("arg_iterator.zig").ArgIterator;

    pub const CoreError = @import("errors.zig").CoreError;
    pub const Context = @import("../context/context.zig").Context;
    pub const Action = @import("../actions/action.zig").Action;
    pub const Command = @import("../commands/command.zig").Command;

    pub const constants = @import("constants.zig");

    // Fields
    allocator: Allocator,
    reader: Reader,
    writer: Writer,
    commands: []const Command,

    // Lifecycle
    pub fn init(
        allocator: Allocator,
        reader: Reader,
        writer: Writer,
        commands: []const Command,
    ) !*Core {
        const instance = try allocator.create(Core);

        instance.* = Core{
            .allocator = allocator,
            .reader = reader,
            .writer = writer,
            .commands = commands,
        };

        return instance;
    }

    pub fn deinit(self: *Core) void {
        self.allocator.destroy(self);
    }

    pub fn run(self: *Core) !void {
        const allocator = self.allocator;

        var args_iter = try ArgIterator.fromProcessArgs(allocator);
        defer args_iter.deinit();

        // Skip the program name
        _ = args_iter.next();

        const command_name = args_iter.next() orelse {
            try self.printCommands();
            return;
        };

        const command = self.findCommand(command_name) orelse {
            try self.writer.print("Error: Unknown command '{s}'\n", .{command_name});
            try self.printCommands();
            return;
        };

        command.execute(command, self, &args_iter) catch |err| {
            self.writer.print("Error: Command '{s}' executing failed '{!}'\n", .{ command_name, err }) catch {};
        };
    }

    // Private
    pub fn findCommand(self: *const Core, name: []const u8) ?*const Command {
        for (self.commands) |*command| {
            if (std.mem.eql(u8, command.name, name)) {
                return command;
            }
        }
        return null;
    }

    pub fn printCommands(self: *Core) !void {
        try self.writer.print("Available commands:\n", .{});
        for (self.commands) |command| {
            try self.writer.print("  {s:<12} {s}\n", .{ command.name, command.description });
        }
        try self.writer.print("\n", .{});
    }
};
