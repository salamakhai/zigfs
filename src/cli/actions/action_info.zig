const std = @import("std");

const fslib = @import("fslib");
const FileSystem = fslib.FileSystem;
const Ext4 = FileSystem.Ext4;

const Core = @import("../core/core.zig").Core;
const Action = Core.Action;
const Context = Core.Context;
const Allocator = Core.Allocator;
const Writer = Core.Writer;
const ArgIterator = Core.ArgIterator;
const ActionError = Action.ActionError;

// Public
pub fn createAction() Action {
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

    const fs_ctx = context.filesystem orelse {
        writer.print("Error: Context should be FileSystem!\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    const filesystem = fs_ctx.filesystem;
    const ext4_fs = filesystem.get(Ext4) catch {
        writer.print("Error: Unsupported filesystem type\n", .{}) catch {};
        return ActionError.UnsupportedFormat;
    };

    writer.print("Filesystem information:\n", .{}) catch {};
    
    const fs_type = switch (filesystem.resolve()) {
        .ext4 => "ext4",
    };
    
    const superblock = &ext4_fs.superblock;
    const block_size = superblock.blockSize();
    const total_blocks = superblock.layout.s_blocks_count_lo;
    const free_blocks = superblock.layout.s_free_blocks_count_lo;
    const total_inodes = superblock.layout.s_inodes_count;
    const free_inodes = superblock.layout.s_free_inodes_count;
    
    writer.print("  Type: {s}\n", .{fs_type}) catch {};
    writer.print("  Block size: {} bytes\n", .{block_size}) catch {};
    writer.print("  Total blocks: {}\n", .{total_blocks}) catch {};
    writer.print("  Free blocks: {}\n", .{free_blocks}) catch {};
    writer.print("  Total size: {} bytes\n", .{@as(u64, total_blocks) * block_size}) catch {};
    writer.print("  Free size: {} bytes\n", .{@as(u64, free_blocks) * block_size}) catch {};
    writer.print("  Total inodes: {}\n", .{total_inodes}) catch {};
    writer.print("  Free inodes: {}\n", .{free_inodes}) catch {};
    writer.print("  Blocks per group: {}\n", .{superblock.layout.s_blocks_per_group}) catch {};
    writer.print("  Inodes per group: {}\n", .{superblock.layout.s_inodes_per_group}) catch {};
}
