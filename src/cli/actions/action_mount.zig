const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const AgrIterator = Core.ArgIterator;

const fslib = @import("fslib");
const FileSystemError = fslib.FileSystemError;
const FileSystemImpl = fslib.FileSystemImpl;

// Public
pub fn NewAction() Action {
    return Action{
        .name = "mount",
        .description = "Mount file system image to the context",
        .invoke = invoke,
    };
}

// Private
fn invoke(
    context: *Context,
    allocator: *Allocator,
    arguments: *AgrIterator,
    writer: *Writer,
) anyerror!void {
    if (arguments.len == 0) {
        try writer.print("Error: No mounting file specified\n", .{});
        return;
    }

    const file_path = arguments[0];

    try writer.print("Opening file: {s}...\n", .{file_path});

    const file = std.fs.cwd().openFile(
        file_path,
        .{ .mode = .read_only },
    ) catch |err| {
        try writer.print("File open error: {!}\n", .{err});
        return err;
    };
    errdefer file.close();

    const filesystem = allocator.create(FileSystemImpl) catch |err| {
        try writer.print("Memory allocation error: {!}\n", .{err});
        return err;
    };

    filesystem.* = FileSystemImpl.fromFile(
        allocator,
        file,
    ) catch |err| {
        try writer.print("Filesystem initialization error: {!}\n", .{err});
        allocator.destroy(filesystem);
        return err;
    };

    context.newFrom(filesystem);

    try writer.print("Filesystem detected and mounted successfully\n", .{});
}
