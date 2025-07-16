const std = @import("std");
const cli = @import("cli");

const Core = cli.Core;
const Command = Core.Command;

const DebugAllocator = std.heap.DebugAllocator;
const ArenaAllocator = std.heap.ArenaAllocator;

pub const ExitCode = enum(u8) {
    Success = 0,
    GeneralError = 1,
    CommandError = 2,
    MemoryError = 3,
    InitError = 4,
    SignalError = 5,
};

/// Supported commands
pub const commands = &[_]Command{
    cli.command_help,
    cli.command_info,
    cli.command_ls,
    cli.command_cat,
    cli.command_browse,
};

/// Application entry
pub fn main() !u8 {
    var main_allocator = DebugAllocator(.{}){};
    defer {
        const leaked = main_allocator.deinit();
        if (leaked == .leak) {
            std.debug.print("Warning: Memory leaks detected\n", .{});
        }
    }

    const allocator = main_allocator.allocator();
    const std_reader = std.io.getStdIn().reader().any();
    const std_writer = std.io.getStdOut().writer().any();

    const core = try Core.init(
        allocator,
        std_reader,
        std_writer,
        commands,
    );
    defer core.deinit();

    core.run() catch |err| {
        switch (err) {
            error.OutOfMemory => {
                try std_writer.print("Error: Out of memory\n", .{});
                return @intFromEnum(ExitCode.MemoryError);
            },
            else => {
                try std_writer.print("Command error: {s}\n", .{@errorName(err)});
                return @intFromEnum(ExitCode.CommandError);
            },
        }
    };

    return @intFromEnum(ExitCode.Success);
}
