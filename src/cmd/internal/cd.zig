const std = @import("std");
const types = @import("cli_types");

pub const CdError = error{
    DirectoryChangeFailed,
    AccessDenied,
    FileNotFound,
    NotDir,
    HomeDirNotFound,
    PathTooLong,
    OutOfMemory,
    WriteError,
};

/// Main function to handle the cd command
///
/// Args:
///   allocator: Memory allocator
///   args: Command arguments (first arg is the path, defaults to home directory)
///   writer: Output writer
pub fn execute(allocator: std.mem.Allocator, args: []const []const u8, writer: types.cmd.Writer) !void {
    const path_arg = if (args.len > 0) args[0] else null;
    const target_path = try resolvePath(allocator, path_arg);

    defer allocator.free(target_path);

    if (std.fs.cwd().openDir(target_path, .{})) |dir| {
        var mutable_dir = dir;
        defer mutable_dir.close();

        mutable_dir.setAsCwd() catch {
            return CdError.DirectoryChangeFailed;
        };

        try writer.print("Changed directory to: {s}\n", .{target_path});
    } else |err| {
        switch (err) {
            error.FileNotFound => return CdError.FileNotFound,
            error.AccessDenied => return CdError.AccessDenied,
            error.NotDir => return CdError.NotDir,
            else => return CdError.DirectoryChangeFailed,
        }
    }
}

// ----PRIVATE----

fn resolvePath(allocator: std.mem.Allocator, path_arg: ?[]const u8) ![]const u8 {
    if (path_arg == null or path_arg.?.len == 0 or std.mem.eql(u8, path_arg.?, "~")) {
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
            switch (err) {
                error.EnvironmentVariableNotFound => return CdError.HomeDirNotFound,
                else => return err,
            }
        };
        return home;
    }

    return allocator.dupe(u8, path_arg.?);
}
