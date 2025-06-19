const std = @import("std");
const cli = @import("cli");
const fslib = @import("fslib");

pub const ACTION = cli.Action{
    .name = "ls",
    .description = "List directory contents",
    .generalHelp = getHelp,
    .process = process,
};

fn getHelp(self: *const cli.Action) []const u8 {
    _ = self;
    return 
    \\Usage: ls [path]
    \\
    \\List the contents of a directory.
    \\If no path is provided, lists the current directory (root).
    \\
    \\Examples:
    \\  ls           - List current directory contents
    \\  ls /etc      - List contents of /etc directory
    ;
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

fn process(
    self: *cli.Action,
    core: *cli.Core,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = reader;

    const mounted_fs = @as(*fslib.FileSystemImpl, @ptrCast(@alignCast(self.context.?)));

    const path = if (args.len > 0) args[0] else "/";

    const dir_entry = mounted_fs.getEntry(
        core.allocator,
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

    const entries = mounted_fs.listDirectory(core.allocator, &dir_entry) catch |err| {
        try writer.print("Error listing directory '{s}': {!}\n", .{ path, err });
        return err;
    };
    defer {
        for (entries) |entry| {
            core.allocator.free(entry.name);
        }
        core.allocator.free(entries);
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
