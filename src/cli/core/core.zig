const std = @import("std");

pub const Core = struct {
    // Types
    pub const Allocator = std.mem.Allocator;
    pub const Reader = std.io.AnyReader;
    pub const Writer = std.io.AnyWriter;
    pub const ArgIterator = std.process.ArgIterator;

    pub const Action = @import("../actions/action.zig").Action;
    pub const Command = @import("../commands/command.zig").Command;

    const CoreError = @import("errors.zig").CoreError;

    pub const Context = @import("context.zig").Context;
    const constants = @import("constants.zig");
    const parser = @import("parser.zig");
    const renderer = @import("renderer.zig");

    // Fields
    allocator: Allocator,
    reader: Reader,
    writer: Writer,
    registry: []const Command,

    // Lifecycle
    pub fn init(
        allocator: Allocator,
        reader: Reader,
        writer: Writer,
        registry: []const Command,
    ) !*Core {
        const instance = try allocator.create(Core);

        instance.* = Core{
            .allocator = allocator,
            .reader = reader,
            .writer = writer,
            .registry = registry,
        };

        return instance;
    }

    pub fn deinit(self: *Core) void {
        self.allocator.destroy(self);
    }

    pub fn run(self: *Core) !void {
        const allocator = self.allocator;

        var args_iter = try std.process.argsWithAllocator(allocator);
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

    // Public
    // public api, building blocks for commands.

    // Private
    pub fn findCommand(self: *const Core, name: []const u8) ?*const Command {
        for (self.registry) |*command| {
            if (std.mem.eql(u8, command.name, name)) {
                return command;
            }
        }
        return null;
    }

    pub fn printCommands(self: *Core) !void {
        try self.writer.print("Available commands:\n", .{});
        for (self.registry) |command| {
            try self.writer.print("  {s:<12} {s}\n", .{ command.name, command.description });
        }
        try self.writer.print("\n", .{});
    }
};
