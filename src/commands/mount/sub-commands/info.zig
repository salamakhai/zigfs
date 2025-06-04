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
    const context_fs = @as(*mount.FileSystemImpl, @ptrCast(@alignCast(context)));

    try writer.print("Filesystem information:\n", .{});
    switch (context_fs.*) {
        .ext4 => |fs| {
            try writer.print("  Type: ext4\n", .{});
            try writer.print("  Block size: {} bytes\n", .{fs.block_size});
            try writer.print("  Total inodes: {}\n", .{fs.superblock.s_inodes_count});
            try writer.print("  Total blocks: {}\n", .{fs.superblock.s_blocks_count_lo});
            try writer.print("  Free blocks: {}\n", .{fs.superblock.s_free_blocks_count_lo});
            try writer.print("  Free inodes: {}\n", .{fs.superblock.s_free_inodes_count});
        },
    }

    _ = args;
}
