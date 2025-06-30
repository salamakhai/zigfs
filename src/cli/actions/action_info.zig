const std = @import("std");

const fslib = @import("fslib");
const FileSystemError = fslib.FileSystemError;
const FileSystem = fslib.FileSystem;

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const ArgIterator = Core.ArgIterator;
const ActionError = Action.ActionError;

// Public
pub fn CreateAction() Action {
    return Action{
        .name = "info",
        .description = "Display filesystem information",
        .invoke = invoke,
    };
}

// Private
fn invoke(
    context: *Context,
    allocator: Allocator,
    args: *ArgIterator,
    writer: Writer,
) ActionError!void {
    _ = allocator;
    _ = args;

    const filesystem = context.getFileSystem() orelse {
        writer.print("Error: No filesystem mounted in context!\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    writer.print("Filesystem information:\n", .{}) catch {};
    const info = filesystem.getInfo();
    writer.print("  Type: {s}\n", .{info.fs_type}) catch {};
    writer.print("  Block size: {} bytes\n", .{info.block_size}) catch {};
    writer.print("  Total size: {} bytes\n", .{info.total_size}) catch {};
    writer.print("  Free size: {?} bytes\n", .{info.free_size}) catch {};
    writer.print("  Total entries: {?}\n", .{info.total_entries}) catch {};
    writer.print("  Free entries: {?}\n", .{info.free_entries}) catch {};
}
