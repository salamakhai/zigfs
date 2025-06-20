const std = @import("std");
const cli = @import("cli");
const fslib = @import("fslib");

const sub_actions = [_]*const cli.Action{
    &@import("fs_info.zig").ACTION,
    &@import("fs_ls.zig").ACTION,
    &@import("fs_cut.zig").ACTION,
};

pub const ACTION = cli.Action{
    .name = "browse",
    .description = "Browse filesystem images interactively",
    .generalHelp = getHelp,
    .process = process,
    .interactive = true,
    .sub_actions = &sub_actions,
};

fn getHelp(self: *const cli.Action) []const u8 {
    _ = self;
    return 
    \\Usage: browse <image_file>
    \\
    \\Mount and interactively browse a filesystem image.
    \\
    \\Examples:
    \\  browse disk.img       - Mount and browse disk.img
    \\
    \\Interactive commands:
    \\  info - Show filesystem information
    \\  ls   - List directory contents  
    \\  cd   - Change directory
    \\  help - Show available commands
    \\  exit - Exit browse mode
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
        try writer.print("Error: No image file specified\n", .{});
        try writer.print("Usage: zigfs browse <image_file>\n", .{});
        return;
    }

    const image_path = args[0];

    try writer.print("Opening image: {s}...\n", .{image_path});

    const file = std.fs.cwd().openFile(
        image_path,
        .{ .mode = .read_only },
    ) catch |err| {
        try writer.print("File open error: {!}\n", .{err});
        return err;
    };
    errdefer file.close();

    const mounted_fs = core.allocator.create(fslib.FileSystemImpl) catch |err| {
        try writer.print("Memory allocation error: {!}\n", .{err});
        return err;
    };

    mounted_fs.* = fslib.FileSystemImpl.fromFile(
        core.allocator,
        file,
    ) catch |err| {
        try writer.print("Filesystem initialization error: {!}\n", .{err});
        core.allocator.destroy(mounted_fs);
        return err;
    };

    try writer.print("Filesystem detected and mounted successfully\n", .{});

    // Show root entry info
    const root_entry = mounted_fs.getRootEntry(core.allocator) catch |err| {
        try writer.print("Failed to read root entry: {!}\n", .{err});
        return err;
    };

    try writer.print("Root directory info:\n", .{});
    try writer.print("  Name: {s}\n", .{root_entry.name});
    try writer.print("  Type: {s}\n", .{@tagName(root_entry.entry_type)});
    try writer.print("  Mode: 0x{X:0>4}\n", .{root_entry.mode});
    try writer.print("  Size: {} bytes\n", .{root_entry.size});
    try writer.print("\n", .{});

    // Store filesystem context for sub-actions
    self.context = mounted_fs;
}
