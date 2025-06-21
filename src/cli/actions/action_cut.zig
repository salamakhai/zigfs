const std = @import("std");

const fslib = @import("fslib");
const FileSystemError = fslib.FileSystemError;
const FileSystem = fslib.FileSystem;

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const AgrIterator = Core.ArgIterator;
const ActionError = Action.ActionError;

// Public
pub fn NewAction() Action {
    return Action{
        .name = "cut",
        .description = "Extract data from a file",
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
        writer.print("Error: No file path specified\n", .{}) catch {};
        writer.print("Usage: cut <file_path> [output_file]\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    const output_file = arguments.next();

    const filesystem = context.getFileSystem() orelse {
        writer.print("Error: Context should be FileSystem!\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    const file_entry = filesystem.getEntry(
        allocator,
        file_path,
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
    defer allocator.free(file_entry.name);

    if (!file_entry.isFile()) {
        writer.print("Error: '{s}' is not a file\n", .{file_path}) catch {};
        return ActionError.NotFile;
    }

    const file_data = filesystem.readFile(allocator, &file_entry) catch |err| {
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
