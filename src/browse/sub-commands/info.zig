const std = @import("std");
const cli = @import("cli");

const browse = @import("../browse.zig");

pub const LsError = error{};

pub const SubCommand = cli.SubCommand{
    .name = "info",
    .description = "info",
    .help =
    \\
    \\
    ,
    .process = subProcess,
};

pub fn subProcess(
    self: *cli.SubCommand,
    command: *cli.Command,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = self;
    _ = reader;

    const context = command.context;
    const contextImage = @as(*browse.Image, @ptrCast(@alignCast(context)));

    try writer.print("Filesystem information:\n", .{});
    try writer.print("  Block size: {} bytes\n", .{contextImage.block_size});
    try writer.print("  Total inodes: {}\n", .{contextImage.superblock.s_inodes_count});
    try writer.print("  Total blocks: {}\n", .{contextImage.superblock.s_blocks_count_lo});
    try writer.print("  Free blocks: {}\n", .{contextImage.superblock.s_free_blocks_count_lo});
    try writer.print("  Free inodes: {}\n", .{contextImage.superblock.s_free_inodes_count});

    _ = args;
}
