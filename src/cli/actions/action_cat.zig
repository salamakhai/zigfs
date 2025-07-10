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
pub fn CreateAction() Action {
    return Action{
        .name = "cat",
        .description = "Extract data from a file",
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
    const file_path = args.next() orelse {
        writer.print("Error: No file path specified\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    const output_file = args.next();

    const fs_ctx = context.filesystem orelse {
        writer.print("Error: Context should be FileSystem!\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    const filesystem = fs_ctx.filesystem;
    const ext4_fs = filesystem.get(Ext4) catch {
        writer.print("Error: Unsupported filesystem type\n", .{}) catch {};
        return ActionError.UnsupportedFormat;
    };

    const desired_path = fs_ctx.session.buildCurrentPath(allocator, file_path) catch {
        writer.print("Error: Failed to build path\n", .{}) catch {};
        return ActionError.OutOfMemory;
    };
    defer allocator.free(desired_path);

    const file_entry = ext4_fs.getEntry(
        allocator,
        desired_path,
    ) catch |err| {
        switch (err) {
            error.EntryNotFound => {
                writer.print("Error: File '{s}' not found\n", .{file_path}) catch {};
                return ActionError.EntryNotFound;
            },
            else => {
                writer.print("Error reading file '{s}': {!}\n", .{ file_path, err }) catch {};
                return ActionError.ReadError;
            },
        }
    };

    if (!file_entry.isFile()) {
        writer.print("Error: '{s}' is not a file\n", .{file_path}) catch {};
        return ActionError.NotFile;
    }

    const file_data = ext4_fs.extractFile(&file_entry) catch |err| {
        writer.print("Error reading file '{s}': {!}\n", .{ file_path, err }) catch {};
        return ActionError.ReadError;
    };
    defer allocator.free(file_data);

    // Output
    if (output_file) |out_path| {
        const out_file = std.fs.cwd().createFile(out_path, .{}) catch |err| {
            writer.print("Error creating output file '{s}': {!}\n", .{ out_path, err }) catch {};
            return ActionError.WriteError;
        };
        defer out_file.close();

        _ = out_file.writeAll(file_data) catch |err| {
            writer.print("Error writing to output file '{s}': {!}\n", .{ out_path, err }) catch {};
            return ActionError.WriteError;
        };

        writer.print("File '{s}' extracted to '{s}' ({} bytes)\n", .{ file_path, out_path, file_data.len }) catch {};
    } else {
        writer.print("Content of '{s}' ({} bytes):\n", .{ file_path, file_data.len }) catch {};
        writer.print("{s}", .{file_data}) catch {};

        if (file_data.len > 0 and file_data[file_data.len - 1] != '\n') {
            writer.print("\n", .{}) catch {};
        }
    }
}
