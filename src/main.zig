const std = @import("std");
const cli = @import("cli");
const Core = cli.Core;

const Allocator = std.heap.GeneralPurposeAllocator;
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

/// Application entry
pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("Warning: Memory leaks detected\n", .{});
        }
    }

    const allocator = gpa.allocator();
    const std_reader = std.io.getStdIn().reader().any();
    const std_writer = std.io.getStdOut().writer().any();

    const core = try cli.InitCore(
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
