const std = @import("std");
const cli = @import("cli");
const Allocator = std.mem.Allocator;
const fs = std.fs;

// TODO: Fix mulatability problems, need to be const
var subCommands = [_]cli.SubCommand{
    @import("sub-commands/info.zig").SubCommand,
};

pub const FileSystem = @import("fs/FileSystem.zig").FileSystem;
pub const FileSystemError = @import("fs/FileSystem.zig").FileSystemError;

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

    const mounted_fs = FileSystem.init(
        runner.core.allocator,
        file,
    ) catch |err| {
        try writer.print("File system init Error: {!}\n", .{err});
        return err;
    };

    try writer.print("\n", .{});
    try mounted_fs.superblock.validate(writer);
    try writer.print("\n", .{});

    self.context = mounted_fs;
}
