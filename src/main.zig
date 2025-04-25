const std = @import("std");
const cli = @import("cli");

const registry = @import("registry.zig");

pub const ExitCode = enum(u8) {
    Success = 0,
    GeneralError = 1,
    CommandError = 2,
    MemoryError = 3,
    InitError = 4,
    SignalError = 5,
};

/// Application entry
pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("Warning: Memory leaks detected\n", .{});
        }
    }

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();
    const stderr = std.io.getStdErr().writer();

    // Create a mutable copy of the commands
    const commands = try allocator.alloc(cli.Command, registry.commands.len);
    @memcpy(commands, registry.commands);

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    const core = try cli.Core.init(
        allocator,
        std.io.getStdIn().reader().any(),
        std.io.getStdOut().writer().any(),
        commands,
    );
    defer core.deinit();
    core.processArgs(&args_iter) catch |err| {
        switch (err) {
            error.OutOfMemory => {
                try stderr.print("Error: Out of memory\n", .{});
                return @intFromEnum(ExitCode.MemoryError);
            },
            else => {
                try stderr.print("Command error: {s}\n", .{@errorName(err)});
                return @intFromEnum(ExitCode.CommandError);
            },
        }
    };

    return @intFromEnum(ExitCode.Success);
}
