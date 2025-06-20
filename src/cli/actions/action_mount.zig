const std = @import("std");

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const AgrIterator = Core.ArgIterator;
const ActionError = Action.ActionError;

const fslib = @import("fslib");
const FileSystemError = fslib.FileSystemError;
const FileSystem = fslib.FileSystem;

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
    allocator: Allocator,
    arguments: *AgrIterator,
    writer: Writer,
) ActionError!void {
    const file_path = arguments.next() orelse {
        writer.print("Error: No mounting file specified\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    writer.print("Opening file: {s}...\n", .{file_path}) catch {};

    const file = std.fs.cwd().openFile(
        file_path,
        .{ .mode = .read_only },
    ) catch |err| {
        writer.print("File open error: {!}\n", .{err}) catch {};
        return switch (err) {
            error.FileNotFound => ActionError.FileNotFound,
            error.AccessDenied => ActionError.AccessDenied,
            else => ActionError.ReadError,
        };
    };
    errdefer file.close();

    const filesystem = allocator.create(FileSystem) catch {
        writer.print("Memory allocation error\n", .{}) catch {};
        return ActionError.OutOfMemory;
    };

    filesystem.* = FileSystem.fromFile(
        allocator,
        file,
    ) catch |err| {
        writer.print("Filesystem initialization error: {!}\n", .{err}) catch {};
        allocator.destroy(filesystem);
        return switch (err) {
            error.UnsupportedFormat => ActionError.UnsupportedFormat,
            error.ReadError => ActionError.ReadError,
            else => ActionError.ReadError,
        };
    };

    context.newFrom(filesystem);

    writer.print("Filesystem detected and mounted successfully\n", .{}) catch {};
}
