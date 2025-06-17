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

fn process(
    self: *cli.Action,
    core: *cli.Core,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = reader;

    // Get filesystem context from parent browse action
    if (self.context == null) {
        try writer.print("Error: No filesystem mounted. Use 'browse' command first.\n", .{});
        return;
    }

    const mounted_fs = @as(*fslib.FileSystemImpl, @ptrCast(@alignCast(self.context.?)));

    // Determine path to list
    const path = if (args.len > 0) args[0] else "/";

    // Get the directory entry
    const dir_entry = mounted_fs.getEntry(core.allocator, path) catch |err| switch (err) {
        error.EntryNotFound => {
            try writer.print("Error: Path '{s}' not found\n", .{path});
            return;
        },
        else => {
            try writer.print("Error reading path '{s}': {!}\n", .{ path, err });
            return err;
        },
    };

    // Check if it's a directory
    if (!dir_entry.isDirectory()) {
        try writer.print("Error: '{s}' is not a directory\n", .{path});
        return;
    }

    // List directory contents
    const entries = mounted_fs.listDirectory(core.allocator, &dir_entry) catch |err| {
        try writer.print("Error listing directory '{s}': {!}\n", .{ path, err });
        return err;
    };
    defer {
        // Free entry names and the entries array
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
    try writer.print("{s:<20} {s:<10} {s:<8} {s}\n", .{ "Name", "Type", "Mode", "Size" });
    try writer.print("{s}\n", .{"-" ** 50});

    // Print entries
    for (entries) |entry| {
        const type_str = switch (entry.entry_type) {
            .file => "file",
            .directory => "dir",
            .symlink => "link",
            .unknown => "unknown",
        };

        try writer.print("{s:<20} {s:<10} 0x{X:0>4} {}\n", .{
            entry.name,
            type_str,
            entry.mode,
            entry.size,
        });
    }

    try writer.print("\nTotal: {} entries\n", .{entries.len});
}
