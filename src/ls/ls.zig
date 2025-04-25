const std = @import("std");
const cli = @import("cli");

pub const LsError = error{
    PathNotFound,
    AccessDenied,
    NotADirectory,
    ReadDirError,
};

/// Main function to handle the ls command
///
/// Args:
///   allocator: Memory allocator (unused)
///   args: Command arguments (first arg is the path, defaults to current directory)
///   writer: Output writer
pub fn process(
    self: *cli.Command,
    runner: *cli.Runner,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = self;
    _ = runner;
    _ = reader;

    const path = if (args.len > 0) args[0] else ".";
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        switch (err) {
            error.FileNotFound => return LsError.PathNotFound,
            error.AccessDenied => return LsError.AccessDenied,
            error.NotDir => return LsError.NotADirectory,
            else => return err,
        }
    };
    defer dir.close();
    var dir_iterator = dir.iterate();

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
