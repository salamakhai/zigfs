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
pub fn CreateAction() Action {
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

    const entries = ext4_fs.listDirectory(allocator, &dir_entry) catch |err| {
        writer.print("Error listing directory '{s}': {!}\n", .{ path, err }) catch {};
        return ActionError.ReadError;
    };
    defer {
        for (entries) |entry| {
            if (entry.name) |name| {
                allocator.free(name);
            }
        }
        allocator.free(entries);
    }

    if (entries.len == 0) {
        writer.print("Directory is empty\n", .{}) catch {};
        return;
    }

    // Print header
    writer.print("{s:<25} {s:<10} {s:<15} {s}\n", .{ "Name", "Type", "Permissions", "Size" }) catch {};
    writer.print("{s}\n", .{"-" ** 62}) catch {};

    // Print entries
    for (entries) |entry| {
        const entry_name = entry.name orelse "<unknown>";
        
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

        // Get inode information for size and mode
        const inode = ext4_fs.reader.readInode(entry.inodeNumber()) catch |err| {
            writer.print("Error reading inode for '{s}': {!}\n", .{ entry_name, err }) catch {};
            continue;
        };

        var size_buffer: [32]u8 = undefined;
        const formatted_size = formatFileSize(inode.size(), &size_buffer) catch "N/A";

        var perm_buffer: [10]u8 = undefined;
        const formatted_perms = inode.formatPermissions(&perm_buffer) catch "?????????";

        writer.print(
            "{s:<25} {s:<10} {s:<15} {s}\n",
            .{
                entry_name,
                type_str,
                formatted_perms,
                formatted_size,
            },
        ) catch {
            return ActionError.WriteError;
        };
    }

    // Print total
    writer.print(
        "\nTotal: {} entries\n",
        .{entries.len},
    ) catch {};
}

fn formatFileSize(size: u64, buffer: []u8) ![]const u8 {
    if (size < 1024) {
        return std.fmt.bufPrint(buffer, "{} B", .{size});
    } else if (size < 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} KB", .{@as(f64, @floatFromInt(size)) / 1024.0});
    } else if (size < 1024 * 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} MB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0)});
    } else {
        return std.fmt.bufPrint(buffer, "{d:.1} GB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0 * 1024.0)});
    }
}
