const std = @import("std");
const cli = @import("cli");
const efs = @import("efs");

pub const SUB_ACTION = cli.SubAction{
    .name = "info",
    .description = "Show filesystem information",
    .help =
    \\Usage: info
    \\
    \\Display detailed information about the mounted filesystem,
    \\including type, block size, and usage statistics.
    ,
    .process = process,
};

fn process(
    self: *const cli.SubAction,
    action: *cli.Action,
    args: []const []const u8,
    reader: cli.Reader,
    writer: cli.Writer,
) anyerror!void {
    _ = self;
    _ = args;
    _ = reader;

    const context = action.context orelse {
        try writer.print("Error: No filesystem mounted\n", .{});
        return;
    };

    const context_fs = @as(*efs.FileSystemImpl, @ptrCast(@alignCast(context)));

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
}
