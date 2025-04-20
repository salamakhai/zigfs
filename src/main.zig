const std = @import("std");
const cli = @import("cli");
const cmd = @import("cmd");

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

    signalHandlers() catch |err| {
        try stderr.print("Warning: Could not set up signal handlers: {s}\n", .{@errorName(err)});
        // Continue execution - this is non-fatal
    };

    cli.handleCmdArgs(cmd.Registry, allocator) catch |err| {
        switch (err) {
            error.OutOfMemory => {
                try stderr.print("Error: Out of memory\n", .{});
                return @intFromEnum(ExitCode.MemoryError);
            },
            else => {
                // All other errors are already handled by cli.handleArgs
                try stderr.print("Command error: {s}\n", .{@errorName(err)});
                return @intFromEnum(ExitCode.CommandError);
            },
        }
    };
    return @intFromEnum(ExitCode.Success);
}

// ----PRIVATE----
fn signalHandlers() !void {
    // Handlers for SIGINT, SIGTERM, etc.
}

fn handleShutdown() void {
    // Cleanup
    std.debug.print("Shutting down...\n", .{});
}
