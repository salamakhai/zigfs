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
        .name = "ls",
        .description = "List directory contents",
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
    const path = arguments.next() orelse "/";

    const filesystem = context.castTo(FileSystem) catch |err| {
        writer.print("Error: Context should be FileSystem! {!}\n", .{err}) catch {};
        return ActionError.InvalidPath;
    };

    const dir_entry = filesystem.getEntry(
        allocator,
        path,
    ) catch |err| {
        switch (err) {
            error.EntryNotFound => {
                writer.print("Error: Path '{s}' not found\n", .{path}) catch {};
                return ActionError.EntryNotFound;
            },
            else => {
                writer.print("Error reading path '{s}': {!}\n", .{ path, err }) catch {};
                return ActionError.ReadError;
            },
        }
    };

    if (!dir_entry.isDirectory()) {
        writer.print("Error: '{s}' is not a directory\n", .{path}) catch {};
        return ActionError.NotDirectory;
    }

    const entries = filesystem.listDirectory(allocator, &dir_entry) catch |err| {
        writer.print("Error listing directory '{s}': {!}\n", .{ path, err }) catch {};
        return ActionError.ReadError;
    };
    defer {
        for (entries) |entry| {
            allocator.free(entry.name);
        }
        allocator.free(entries);
    }

    if (entries.len == 0) {
        writer.print("Directory is empty\n", .{}) catch {};
        return;
    }

    // Print header
    writer.print("Contents of '{s}':\n", .{path}) catch {};
    writer.print("{s:<25} {s:<10} {s:<8} {s}\n", .{ "Name", "Type", "Mode", "Size" }) catch {};
    writer.print("{s}\n", .{"-" ** 60}) catch {};

    // Print entries
    for (entries) |entry| {
        const type_str = switch (entry.entry_type) {
            .file => "file",
            .directory => "dir",
            .symlink => "link",
            .unknown => "unknown",
        };

        var size_buffer: [32]u8 = undefined;
        const formatted_size = formatFileSize(entry.size, &size_buffer) catch "N/A";

        writer.print(
            "{s:<25} {s:<10} 0x{X:0>4} {s}\n",
            .{
                entry.name,
                type_str,
                entry.mode,
                formatted_size,
            },
        ) catch {
            return ActionError.WriteError;
        };
    }

    // Print total
    writer.print(
        "\nTotal: {} entries\n",
        .{entries.len},
    ) catch {};
}

fn formatFileSize(size: u64, buffer: []u8) ![]const u8 {
    if (size < 1024) {
        return std.fmt.bufPrint(buffer, "{} B", .{size});
    } else if (size < 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} KB", .{@as(f64, @floatFromInt(size)) / 1024.0});
    } else if (size < 1024 * 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} MB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0)});
    } else {
        return std.fmt.bufPrint(buffer, "{d:.1} GB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0 * 1024.0)});
    }
}
