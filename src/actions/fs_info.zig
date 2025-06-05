const std = @import("std");
const cli = @import("cli");
const efs = @import("efs");

pub const ACTION = cli.Action{
    .name = "info",
    .description = "Show filesystem information",
    .help = getHelp,
    .process = process,
};

fn getHelp(self: *const cli.Action) []const u8 {
    if (self.parent != null) {
        // Interactive mode help (when used within browse)
        return 
        \\Usage: info
        \\
        \\Display detailed information about the currently mounted filesystem.
        ;
    } else {
        // Standalone mode help
        return 
        \\Usage: info <image_file>
        \\
        \\Display detailed information about a filesystem image.
        \\
        \\Examples:
        \\  info disk.img        - Mount and show info for disk.img
        ;
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

    var context_fs: *efs.FileSystemImpl = undefined;
    var should_cleanup = false;

    if (self.context) |context| {
        context_fs = @as(*efs.FileSystemImpl, @ptrCast(@alignCast(context)));
    } else {
        if (args.len == 0) {
            try writer.print("Error: No filesystem mounted and no image file specified\n", .{});
            try writer.print("Usage: info <image_file>\n", .{});
            return;
        }

        const image_path = args[0];

        const file = std.fs.cwd().openFile(
            image_path,
            .{ .mode = .read_only },
        ) catch |err| {
            try writer.print("Error opening file '{s}': {!}\n", .{ image_path, err });
            return;
        };
        defer if (should_cleanup) {
            file.close();
        };

        // Create and mount filesystem
        const mounted_fs = core.allocator.create(efs.FileSystemImpl) catch |err| {
            try writer.print("Memory allocation error: {!}\n", .{err});
            return;
        };
        defer if (should_cleanup) {
            core.allocator.destroy(mounted_fs);
        };

        mounted_fs.* = efs.FileSystemImpl.fromFile(
            core.allocator,
            file,
        ) catch |err| {
            try writer.print("Filesystem initialization error: {!}\n", .{err});
            core.allocator.destroy(mounted_fs);
            return;
        };

        context_fs = mounted_fs;
        should_cleanup = true;
    }

    try showFilesystemInfo(context_fs, writer);
}

fn showFilesystemInfo(fs: *efs.FileSystemImpl, writer: cli.Writer) !void {
    try writer.print("Filesystem information:\n", .{});
    switch (fs.*) {
        .ext4 => |filesystem| {
            try writer.print("  Type: ext4\n", .{});
            try writer.print("  Block size: {} bytes\n", .{filesystem.block_size});
            try writer.print("  Total inodes: {}\n", .{filesystem.superblock.s_inodes_count});
            try writer.print("  Total blocks: {}\n", .{filesystem.superblock.s_blocks_count_lo});
            try writer.print("  Free blocks: {}\n", .{filesystem.superblock.s_free_blocks_count_lo});
            try writer.print("  Free inodes: {}\n", .{filesystem.superblock.s_free_inodes_count});
        },
    }
}
