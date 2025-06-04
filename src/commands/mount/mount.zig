const std = @import("std");
const cli = @import("cli");
const efs = @import("efs");

const Allocator = std.mem.Allocator;
const fs = std.fs;

// TODO: Fix mulatability problems, need to be const
var subCommands = [_]cli.SubCommand{
    @import("sub-commands/info.zig").SubCommand,
};

pub const FileSystemImpl = efs.FileSystemImpl;
pub const FileSystemError = efs.FileSystemError;

pub const Command = cli.Command{
    .name = "mount",
    .description = "mount [image]",
    .help =
    \\browse [directory]
    \\
    \\
    \\
    \\
    \\Examples:
    \\  
    \\  
    ,
    .process = process,
    .interactive = true,
    .subCommands = &subCommands,
};

//
// Private
//
fn process(
    self: *cli.Command,
    runner: *cli.Runner,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = reader;

    if (args.len == 0) {
        return;
    }

    const image_path = args[0];

    try writer.print("Mounting image: {s}...\n", .{image_path});

    const file = fs.cwd().openFile(
        image_path,
        .{ .mode = .read_only },
    ) catch |err| {
        try writer.print("File open error: {!}\n", .{err});
        return err;
    };
    errdefer file.close();

    var mounted_fs = FileSystemImpl.fromFile(
        runner.core.allocator,
        file,
    ) catch |err| {
        try writer.print("File system init Error: {!}\n", .{err});
        return err;
    };

    try writer.print("Filesystem detected and mounted successfully\n", .{});

    // Test reading root entry
    const root_entry = mounted_fs.getRootEntry(runner.core.allocator) catch |err| {
        try writer.print("Failed to read root entry: {!}\n", .{err});
        return err;
    };

    try writer.print("Root entry info:\n", .{});
    try writer.print("  Name: {s}\n", .{root_entry.name});
    try writer.print("  Type: {s}\n", .{@tagName(root_entry.entry_type)});
    try writer.print("  Mode: 0x{X:0>4}\n", .{root_entry.mode});
    try writer.print("  Size: {} bytes\n", .{root_entry.size});
    try writer.print("\n", .{});

    self.context = &mounted_fs;
}
