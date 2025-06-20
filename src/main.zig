const std = @import("std");
const cli = @import("cli");
const Core = cli.Core;

const action_registry = @import("actions/root.zig");

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
    var main_allocator = std.heap.DebugAllocator(.{}){};

    defer {
        const leaked = main_allocator.deinit();
        if (leaked == .leak) {
            std.debug.print("Warning: Memory leaks detected\n", .{});
        }
    }

    var arena = std.heap.ArenaAllocator.init(main_allocator.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();
    const std_reader = std.io.getStdIn().reader().any();
    const std_writer = std.io.getStdOut().writer().any();

    const core: Core = try cli.InitCore(
        allocator,
        std_reader,
        std_writer,
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
