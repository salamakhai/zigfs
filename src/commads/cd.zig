const std = @import("std");

const Error = error{
    InvalidPath,
    AccessDenied,
    NotADirectory,
};

pub fn run(path: ?[]const u8) !void {
    const target_path = if (path) |p| p else {
        return Error.InvalidPath;
    };
    target_path = std.fs.cwd();
}

pub fn pwd() ![]const u8 {}
