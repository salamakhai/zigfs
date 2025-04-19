const std = @import("std");
const cli = @import("cli.zig");

pub const MainError = error{
    OutOfMemory,
    InitializationFailed,
    SignalError,
    InvalidArgument,
};

pub const ExitCode = enum(u8) {
    Success = 0,
    GeneralError = 1,
    CommandError = 2,
    MemoryError = 3,
    InitError = 4,
    SignalError = 5,
};

/// Handle application shutdown (for future signal handling)
fn handleShutdown() void {
    // Perform any necessary cleanup before program exit
    // This could include saving state, closing connections, etc.
    std.debug.print("Shutting down...\n", .{});
}

/// Setup signal handlers for clean termination
fn setupSignalHandlers() !void {
    // This is a placeholder for signal handling
    // In a real implementation, we would set up handlers for SIGINT, SIGTERM, etc.
    // Since Zig's signal handling is still evolving, this is left as a future enhancement
}

/// Main entry point for the application
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
    
    // Set up signal handlers
    setupSignalHandlers() catch |err| {
        try stderr.print("Warning: Could not set up signal handlers: {s}\n", .{@errorName(err)});
        // Continue execution - this is non-fatal
    };
    
    // Process command line arguments
    cli.handleArgs(allocator) catch |err| {
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
