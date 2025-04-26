const std = @import("std");
const cli = @import("cli");

const mount = @import("../mount.zig");

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
    const context_fs = @as(*mount.FileSystem, @ptrCast(@alignCast(context)));

    try writer.print("Filesystem information:\n", .{});
    try writer.print("  Block size: {} bytes\n", .{context_fs.block_size});
    try writer.print("  Total inodes: {}\n", .{context_fs.superblock.s_inodes_count});
    try writer.print("  Total blocks: {}\n", .{context_fs.superblock.s_blocks_count_lo});
    try writer.print("  Free blocks: {}\n", .{context_fs.superblock.s_free_blocks_count_lo});
    try writer.print("  Free inodes: {}\n", .{context_fs.superblock.s_free_inodes_count});

    _ = args;
}
