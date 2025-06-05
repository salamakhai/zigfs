const std = @import("std");
const cli = @import("cli");

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
    const stderr = std.io.getStdErr().writer();

    // TODO: Decide on mutability of references in structs
    const actions = try allocator.alloc(cli.Action, action_registry.actions.len);
    @memcpy(actions, action_registry.actions);

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    const core = try cli.Core.init(
        allocator,
        std.io.getStdIn().reader().any(),
        std.io.getStdOut().writer().any(),
        actions,
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
