const std = @import("std");
const cli = @import("cli");
const fslib = @import("fslib");

pub const ACTION = cli.Action{
    .name = "cut",
    .description = "Extract data",
    .generalHelp = getHelp,
    .process = process,
};

fn getHelp(self: *const cli.Action) []const u8 {
    _ = self;
    return 
    \\Usage: cut <file_path> [output_file]
    \\
    \\Extract file data from the filesystem.
    \\If no output file is provided, data is written to stdout.
    \\
    \\Examples:
    \\  cut /hello.txt      - Extract and display file contents
    \\  cut /hello.txt out.txt  - Extract file to out.bin
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

    if (args.len == 0) {
        try writer.print("Error: No file path specified\n", .{});
        try writer.print("Usage: cut <file_path> [output_file]\n", .{});
        return;
    }

    const mounted_fs = @as(*fslib.FileSystemImpl, @ptrCast(@alignCast(self.context.?)));
    const file_path = args[0];
    const output_file = if (args.len > 1) args[1] else null;

    // Get the file entry
    const file_entry = mounted_fs.getEntry(
        core.allocator,
        file_path,
    ) catch |err| {
        switch (err) {
            error.EntryNotFound => {
                try writer.print("Error: File '{s}' not found\n", .{file_path});
                return;
            },
            else => {
                try writer.print("Error reading file '{s}': {!}\n", .{ file_path, err });
                return err;
            },
        }
    };
    defer core.allocator.free(file_entry.name);

    if (!file_entry.isFile()) {
        try writer.print("Error: '{s}' is not a file\n", .{file_path});
        return;
    }

    const file_data = mounted_fs.readFile(core.allocator, &file_entry) catch |err| {
        try writer.print("Error reading file '{s}': {!}\n", .{ file_path, err });
        return err;
    };
    defer core.allocator.free(file_data);

    if (output_file) |out_path| {
        // Write to output file
        const out_file = std.fs.cwd().createFile(out_path, .{}) catch |err| {
            try writer.print("Error creating output file '{s}': {!}\n", .{ out_path, err });
            return err;
        };
        defer out_file.close();

        _ = out_file.writeAll(file_data) catch |err| {
            try writer.print("Error writing to output file '{s}': {!}\n", .{ out_path, err });
            return err;
        };

        try writer.print("File '{s}' extracted to '{s}' ({} bytes)\n", .{ file_path, out_path, file_data.len });
    } else {
        // Write to stdout
        try writer.print("Content of '{s}' ({} bytes):\n", .{ file_path, file_data.len });
        try writer.print("{s}", .{file_data});
        if (file_data.len > 0 and file_data[file_data.len - 1] != '\n') {
            try writer.print("\n", .{});
        }
    }
}
