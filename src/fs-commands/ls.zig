const std = @import("std");
const cli = @import("../cli.zig");

pub const LsError = error{
    PathNotFound,
    AccessDenied,
    NotADirectory,
    OutOfMemory,
    ReadDirError,
    WriteError,
};

/// Main function to handle the ls command
/// 
/// Args:
///   allocator: Memory allocator (unused)
///   args: Command arguments (first arg is the path, defaults to current directory)
///   writer: Output writer
pub fn execute(
    allocator: std.mem.Allocator,
    args: []const []const u8, 
    writer: cli.Writer
) !void {
    _ = allocator;

    // Path to list
    const path = if (args.len > 0) args[0] else ".";
    
    // Open the directory
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        switch (err) {
            error.FileNotFound => return LsError.PathNotFound,
            error.AccessDenied => return LsError.AccessDenied,
            error.NotDir => return LsError.NotADirectory,
            else => return err,
        }
    };
    defer dir.close();
    
    // Iterate through entries
    var dir_iterator = dir.iterate();
    
    // Write list
    try writer.print("Contents of '{s}':\n", .{path});
    
    while (dir_iterator.next() catch |err| {
        switch (err) {
            error.AccessDenied => return LsError.AccessDenied,
            else => return LsError.ReadDirError,
        }
    }) |entry| {
        try writer.print("{s}\n", .{entry.name});
    }
}