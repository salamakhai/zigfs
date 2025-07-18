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
        .name = "ls",
        .description = "List directory contents",
        .invoke = invoke,
    };
}

// Private
fn invoke(
    context: *Context,
    allocator: Allocator,
    arguments: *ArgIterator,
    writer: Writer,
) ActionError!void {
    const fs_ctx = context.filesystem orelse {
        writer.print("Error: Context should be FileSystem!\n", .{}) catch {};
        return ActionError.InvalidPath;
    };

    const path = arguments.next() orelse ".";

    const filesystem = fs_ctx.filesystem;
    const ext4_fs = filesystem.get(Ext4) catch {
        writer.print("Error: Unsupported filesystem type\n", .{}) catch {};
        return ActionError.UnsupportedFormat;
    };

    const target_path = try fs_ctx.session.buildCurrentPath(allocator, path);
    defer allocator.free(target_path);

    const dir_entry = ext4_fs.getEntry(
        allocator,
        target_path,
    ) catch |err| {
        switch (err) {
            error.EntryNotFound => {
                writer.print("Error: Path '{s}' not found\n", .{path}) catch {};
                return ActionError.EntryNotFound;
            },
            else => {
                writer.print("Error reading path '{s}': {!}\n", .{ path, err }) catch {};
                return ActionError.ReadError;
            },
        }
    };

    if (!dir_entry.isDirectory()) {
        writer.print("Error: '{s}' is not a directory\n", .{path}) catch {};
        return ActionError.NotDirectory;
    }

    var dir_context = ext4_fs.readDirectoryContext(allocator, &dir_entry) catch |err| {
        writer.print("Error listing directory '{s}': {!}\n", .{ path, err }) catch {};
        return ActionError.ReadError;
    };
    defer dir_context.deinit();

    if (dir_context.entries.len == 0) {
        writer.print("Directory is empty\n", .{}) catch {};
        return;
    }

    // Print header
    writer.print("{s:<25} {s:<10} {s:<15} {s:<10} {s:<7}\n", .{ "Name", "Type", "Permissions", "Size", "Volume" }) catch {};
    writer.print("{s}\n", .{"-" ** 72}) catch {};

    // Print entries
    for (0..dir_context.entries.len) |i| {
        const entry = dir_context.entries[i];
        const entry_name = dir_context.getEntryNameByIndex(i);

        const type_str = if (entry.isDirectory())
            "dir"
        else if (entry.isFile())
            "file"
        else if (entry.isSymlink())
            "link"
        else if (entry.isCharacterDevice())
            "chardev"
        else if (entry.isBlockDevice())
            "blockdev"
        else if (entry.isFifo())
            "fifo"
        else if (entry.isSocket())
            "socket"
        else
            "unknown";

        const inode = ext4_fs.disk_reader.readInodeByNumber(
            entry.inodeNumber(),
            ext4_fs.superblock.inodesPerGroup(),
            ext4_fs.superblock.inodeSize(),
        ) catch |err| {
            writer.print("Error reading inode for '{s}': {!}\n", .{ entry_name, err }) catch {};
            continue;
        };

        var size_buffer: [32]u8 = undefined;
        const size: u64 = inode.size();

        const formatted_size = formatFileSize(size, &size_buffer) catch "N/A";

        var perm_buffer: [10]u8 = undefined;
        const formatted_perms = inode.formatPermissions(&perm_buffer) catch "?????????";

        const physical_size = "N/A";

        writer.print(
            "{s:<25} {s:<10} {s:<15} {s:<10} {s:^7}\n",
            .{
                entry_name,
                type_str,
                formatted_perms,
                formatted_size,
                physical_size,
            },
        ) catch {
            return ActionError.WriteError;
        };
    }

    // Print total
    writer.print(
        "\nTotal: {} entries\n",
        .{dir_context.entries.len},
    ) catch {};
}
