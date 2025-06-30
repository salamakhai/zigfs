const std = @import("std");
const Allocator = std.mem.Allocator;

const Inode = @import("../structures/inode.zig").Inode;
const Ext4Entry = @import("../structures/entry.zig").Entry;
const Entry = @import("../../entry.zig").Entry;
const EntryType = @import("../../entry.zig").EntryType;
const Reader = @import("reader.zig").Reader;
const errors = @import("../../errors.zig");

pub const Navigator = struct {
    reader: *const Reader,

    pub fn init(reader: *const Reader) Navigator {
        return Navigator{
            .reader = reader,
        };
    }

    pub fn getRootInode(self: *const Navigator) !Inode {
        return self.reader.readInode(2);
    }

    pub fn getRootEntry(self: *const Navigator, allocator: Allocator) !Entry {
        const root_inode = try self.getRootInode();
        const root_name = try allocator.dupe(u8, "/");

        return Entry{
            .name = root_name,
            .entry_type = if (root_inode.isDirectory()) .directory else .file,
            .size = root_inode.size(),
            .mode = root_inode.i_mode,
            .inode_number = 2,
        };
    }

    pub fn getEntry(self: *const Navigator, allocator: Allocator, path: []const u8) !Entry {
        if (std.mem.eql(u8, path, "/") or path.len == 0) {
            return self.getRootEntry(allocator);
        }

        if (path.len > 4096) {
            return errors.FileSystemError.EntryNotFound;
        }

        var path_components = std.ArrayList([]const u8).init(allocator);
        defer path_components.deinit();

        var iter = std.mem.splitScalar(u8, path, '/');
        while (iter.next()) |component| {
            if (component.len > 0) {
                try path_components.append(component);
            }
        }

        var current_inode = try self.getRootInode();
        var current_name = try allocator.dupe(u8, "/");
        var current_inode_number: u32 = 2;

        for (path_components.items) |component| {
            if (!current_inode.isDirectory()) {
                allocator.free(current_name);
                return errors.FileSystemError.NotDirectory;
            }

            current_inode_number = self.findEntryInDirectory(allocator, &current_inode, component) catch |err| {
                allocator.free(current_name);
                return switch (err) {
                    error.EntryNotFound => errors.FileSystemError.EntryNotFound,
                    error.NotDirectory => errors.FileSystemError.NotDirectory,
                    else => err,
                };
            };

            current_inode = self.reader.readInode(current_inode_number) catch |err| {
                allocator.free(current_name);
                return err;
            };

            if (current_inode.isSymlink()) {
                // TODO: Implement symbolic link resolution
            }

            allocator.free(current_name);
            current_name = try allocator.dupe(u8, component);
        }

        const entry_type: EntryType =
            if (current_inode.isDirectory())
                .directory
            else if (current_inode.isRegularFile())
                .file
            else if (current_inode.isSymlink())
                .symlink
            else
                .unknown;

        return Entry{
            .name = current_name,
            .entry_type = entry_type,
            .size = current_inode.size(),
            .mode = current_inode.i_mode,
            .inode_number = current_inode_number,
        };
    }

    fn findEntryInDirectory(self: *const Navigator, allocator: Allocator, dir_inode: *const Inode, entry_name: []const u8) !u32 {
        if (!dir_inode.isDirectory()) {
            return errors.FileSystemError.NotDirectory;
        }

        const dir_data = try self.reader.readFileData(allocator, dir_inode);
        defer allocator.free(dir_data);

        var offset: usize = 0;
        while (offset < dir_data.len) {
            if (offset + @sizeOf(Ext4Entry) > dir_data.len) {
                break;
            }

            var dir_entry: Ext4Entry = undefined;
            const entry_bytes = std.mem.asBytes(&dir_entry);
            const available_bytes = @min(entry_bytes.len, dir_data.len - offset);
            @memcpy(entry_bytes[0..available_bytes], dir_data[offset .. offset + available_bytes]);

            if (!dir_entry.isValid() or dir_entry.record_len == 0) {
                break;
            }

            if (offset + dir_entry.record_len > dir_data.len) {
                break;
            }

            if (dir_entry.inode != 0) {
                const name = dir_entry.getName(dir_data, offset);
                if (std.mem.eql(u8, name, entry_name)) {
                    return dir_entry.inode;
                }
            }

            offset = dir_entry.nextEntry(offset);
        }

        return errors.FileSystemError.EntryNotFound;
    }
};