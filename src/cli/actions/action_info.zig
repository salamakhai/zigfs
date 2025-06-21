const std = @import("std");

const fslib = @import("fslib");
const FileSystemError = fslib.FileSystemError;
const FileSystem = fslib.FileSystem;

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const ArgIterator = Core.ArgIterator;
const ActionError = Action.ActionError;

// Public
pub fn NewAction() Action {
    return Action{
        .name = "info",
        .description = "Display filesystem information",
        .invoke = invoke,
    };
}

// Private
fn invoke(
    context: *Context,
    allocator: Allocator,
    args: *ArgIterator,
    writer: Writer,
) ActionError!void {
    _ = allocator;
    _ = args;

    const filesystem = context.getFileSystem() orelse {
        writer.print("Error: No filesystem mounted in context!\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    writer.print("Filesystem information:\n", .{}) catch {};
    switch (filesystem.*) {
        .ext4 => |ext4| {
            writer.print("  Type: ext4\n", .{}) catch {};
            writer.print("  Block size: {} bytes\n", .{ext4.block_size}) catch {};
            writer.print("  Total inodes: {}\n", .{ext4.superblock.s_inodes_count}) catch {};
            writer.print("  Total blocks: {}\n", .{ext4.superblock.s_blocks_count_lo}) catch {};
            writer.print("  Free blocks: {}\n", .{ext4.superblock.s_free_blocks_count_lo}) catch {};
            writer.print("  Free inodes: {}\n", .{ext4.superblock.s_free_inodes_count}) catch {};
        },
    }
}
