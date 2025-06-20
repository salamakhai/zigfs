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
        .name = "ls",
        .description = "List directory contents",
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
    const path = arguments.next();

    const filesystem = try context.castTo(FileSystemImpl) catch |err| {
        try writer.print("Error: Context should be '{s}'! {!}\n", .{ FileSystemImpl, err });
    };

    const dir_entry = filesystem.getEntry(
        allocator,
        path,
    ) catch |err| {
        switch (err) {
            error.EntryNotFound => {
                try writer.print("Error: Path '{s}' not found\n", .{path});
                return;
            },
            else => {
                try writer.print("Error reading path '{s}': {!}\n", .{ path, err });
                return err;
            },
        }
    };

    if (!dir_entry.isDirectory()) {
        try writer.print("Error: '{s}' is not a directory\n", .{path});
        return;
    }

    const entries = filesystem.listDirectory(allocator, &dir_entry) catch |err| {
        try writer.print("Error listing directory '{s}': {!}\n", .{ path, err });
        return err;
    };
    defer {
        for (entries) |entry| {
            allocator.free(entry.name);
        }
        allocator.free(entries);
    }

    if (entries.len == 0) {
        try writer.print("Directory is empty\n", .{});
        return;
    }

    // Print header
    try writer.print("Contents of '{s}':\n", .{path});
    try writer.print("{s:<25} {s:<10} {s:<8} {s}\n", .{ "Name", "Type", "Mode", "Size" });
    try writer.print("{s}\n", .{"-" ** 60});

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

        try writer.print(
            "{s:<25} {s:<10} 0x{X:0>4} {s}\n",
            .{
                entry.name,
                type_str,
                entry.mode,
                formatted_size,
            },
        );
    }

    // Print total
    try writer.print(
        "\nTotal: {} entries\n",
        .{entries.len},
    );
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
