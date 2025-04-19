const std = @import("std");
const cli = @import("../cli.zig");

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

/// Resolves path for special cases like:
/// - empty path (changes to home directory)
/// - "~" (changes to home directory)
/// - relative paths (./ or ../)
fn resolvePath(allocator: std.mem.Allocator, path_arg: ?[]const u8) ![]const u8 {
    // If no path provided or "~", use home directory
    if (path_arg == null or path_arg.?.len == 0 or std.mem.eql(u8, path_arg.?, "~")) {
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
            switch (err) {
                error.EnvironmentVariableNotFound => return CdError.HomeDirNotFound,
                else => return err,
            }
        };
        return home;
    }
    
    // Return the path as-is for all other cases
    // The actual path resolution will be handled by std.fs.cwd().openDir()
    return allocator.dupe(u8, path_arg.?);
}

/// Main function to handle the cd command
/// 
/// Args:
///   allocator: Memory allocator
///   args: Command arguments (first arg is the path, defaults to home directory)
///   writer: Output writer
pub fn execute(
    allocator: std.mem.Allocator, 
    args: []const []const u8, 
    writer: cli.Writer
) !void {
    const path_arg = if (args.len > 0) args[0] else null;
    const target_path = try resolvePath(allocator, path_arg);

    defer allocator.free(target_path);
    
    if (std.fs.cwd().openDir(target_path, .{})) |dir| {
        var mutable_dir = dir;
        defer mutable_dir.close();
        
        // Set as current working directory
        mutable_dir.setAsCwd() catch {
            return CdError.DirectoryChangeFailed;
        };
        
        // Success
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