const std = @import("std");
const cli = @import("cli");

pub const FindError = error{
    PathNotFound,
    AccessDenied,
    NotADirectory,
    ReadDirError,
    WriteError,
    OutOfMemory,
};

/// Main function to handle the find command
///
/// Args:
///   allocator: Memory allocator
///   args: Command arguments ([pattern] [path])
///   writer: Output writer
pub fn execute(allocator: std.mem.Allocator, args: []const []const u8, writer: cli.Writer) !void {
    if (args.len < 1) {
        try writer.print("Usage: find pattern [path]\n", .{});
        try writer.print("  pattern: Text to search for in file names\n", .{});
        try writer.print("  path: Directory to search in (defaults to current)\n", .{});
        return FindError.PathNotFound;
    }

    const pattern = args[0];
    const root_path = if (args.len > 1) args[1] else ".";

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();
    const pattern_copy = try arena_allocator.dupe(u8, pattern);

    try searchDirectoryRecursive(arena_allocator, root_path, pattern_copy, writer, 0);
}

// ----PRIVATE----

fn searchDirectoryRecursive(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    pattern: []const u8,
    writer: cli.Writer,
    depth: usize,
) !void {
    if (depth > 32) return;

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        switch (err) {
            error.FileNotFound => return FindError.PathNotFound,
            error.AccessDenied => return FindError.AccessDenied,
            error.NotDir => return FindError.NotADirectory,
            else => return err,
        }
    };
    defer dir.close();

    var dir_iterator = dir.iterate();
    while (dir_iterator.next() catch |err| {
        switch (err) {
            error.AccessDenied => return FindError.AccessDenied,
            else => return FindError.ReadDirError,
        }
    }) |entry| {
        if (std.mem.indexOf(u8, entry.name, pattern) != null) {
            if (dir_path.len > 0 and dir_path[dir_path.len - 1] == '/') {
                try writer.print("{s}{s}\n", .{ dir_path, entry.name });
            } else {
                try writer.print("{s}/{s}\n", .{ dir_path, entry.name });
            }
        }

        if (entry.kind == .directory) {
            var path_buffer = std.ArrayList(u8).init(allocator);
            defer path_buffer.deinit();

            try path_buffer.appendSlice(dir_path);

            if (dir_path.len == 0 or dir_path[dir_path.len - 1] != '/') {
                try path_buffer.append('/');
            }
            try path_buffer.appendSlice(entry.name);

            const new_path = try allocator.dupe(u8, path_buffer.items);

            try searchDirectoryRecursive(allocator, new_path, pattern, writer, depth + 1);
        }
    }
}
