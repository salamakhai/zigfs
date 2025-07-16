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

const formatters = @import("../core/formatters.zig");
const formatFileSize = formatters.formatFileSize;

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

    const fs_type = switch (filesystem.resolve()) {
        .ext4 => "ext4",
    };

    const superblock = &ext4_fs.superblock;
    const block_size = superblock.blockSize();
    const total_blocks = superblock.layout.s_blocks_count_lo;
    const free_blocks = superblock.layout.s_free_blocks_count_lo;
    const used_blocks = total_blocks - free_blocks;
    const total_inodes = superblock.layout.s_inodes_count;
    const free_inodes = superblock.layout.s_free_inodes_count;

    // Format
    const total_size = @as(u64, total_blocks) * block_size;
    const free_size = @as(u64, free_blocks) * block_size;
    const used_size = @as(u64, used_blocks) * block_size;

    var total_size_buf: [32]u8 = undefined;
    var free_size_buf: [32]u8 = undefined;
    var used_size_buf: [32]u8 = undefined;
    var block_size_buf: [32]u8 = undefined;

    const total_size_formatted = formatFileSize(total_size, &total_size_buf) catch "N/A";
    const free_size_formatted = formatFileSize(free_size, &free_size_buf) catch "N/A";
    const used_size_formatted = formatFileSize(used_size, &used_size_buf) catch "N/A";
    const block_size_formatted = formatFileSize(block_size, &block_size_buf) catch "N/A";

    const used_percentage = if (total_size > 0)
        @as(f64, @floatFromInt(used_size)) / @as(f64, @floatFromInt(total_size)) * 100.0
    else
        0.0;

    writer.print(
        \\
        \\FILESYSTEM INFORMATION
        \\======================
        \\ Type: {s}
        \\ Block Size: {s}
        \\
    , .{
        fs_type,
        block_size_formatted,
    }) catch {};

    // Capacity section
    writer.print(
        \\
        \\CAPACITY
        \\----------------------
        \\ Total Space:  {s:<}
        \\ Used Space:   {s:<} ({d:.1}%)
        \\ Available:    {s:<}
        \\
    , .{
        total_size_formatted,
        used_size_formatted,
        used_percentage,
        free_size_formatted,
    }) catch {};

    // Block allocation section
    writer.print(
        \\
        \\ALLOCATION
        \\----------------------
        \\ Total Blocks: {d:<}
        \\ Used Blocks:  {d:<}
        \\ Free Blocks:  {d:<}
        \\ Total Inodes: {d:<}
        \\ Free Inodes:  {d:<}
        \\
    , .{
        total_blocks,
        used_blocks,
        free_blocks,
        total_inodes,
        free_inodes,
    }) catch {};

    writer.print(
        \\
        \\LAYOUT
        \\----------------------
        \\ Blocks/Group: {d:<}
        \\ Inodes/Group: {d:<}
        \\
    , .{
        superblock.layout.s_blocks_per_group,
        superblock.layout.s_inodes_per_group,
    }) catch {};
}
