const std = @import("std");

const fslib = @import("fslib");
const FileSystem = fslib.FileSystem;
const Ext4 = FileSystem.Ext4;

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const ArgIterator = Core.ArgIterator;
const ActionError = Action.ActionError;

// Public
pub fn createAction() Action {
    return Action{
        .name = "cd",
        .description = "Change current working directory",
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
    const path = args.next() orelse {
        writer.print("Error: No path specified\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    var fs_ctx = &(context.filesystem orelse {
        writer.print("Error: No filesystem mounted\n", .{}) catch {};
        return ActionError.InvalidPath;
    });

    const filesystem = fs_ctx.filesystem;
    const ext4_fs = filesystem.get(Ext4) catch {
        writer.print("Error: Unsupported filesystem type\n", .{}) catch {};
        return ActionError.UnsupportedFormat;
    };

    const target_path = fs_ctx.session.buildCurrentPath(allocator, path) catch {
        writer.print("Error: Failed to build path\n", .{}) catch {};
        return ActionError.OutOfMemory;
    };
    defer allocator.free(target_path);

    const entry = ext4_fs.getEntry(allocator, target_path) catch {
        writer.print("Error: Path '{s}' not found\n", .{target_path}) catch {};
        return ActionError.InvalidPath;
    };
    defer if (entry.name) |name| allocator.free(name);

    if (!entry.isDirectory()) {
        writer.print("Error: '{s}' is not a directory\n", .{target_path}) catch {};
        return ActionError.InvalidPath;
    }

    fs_ctx.session.setCurrentDirectory(target_path) catch {
        writer.print("Error: Failed to change directory\n", .{}) catch {};
        return ActionError.OutOfMemory;
    };
}
