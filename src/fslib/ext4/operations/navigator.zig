const std = @import("std");
const Allocator = std.mem.Allocator;

const Inode = @import("../structures/inode.zig").Inode;
const Entry = @import("../structures/entry.zig").Entry;
const FilesystemEntry = @import("../structures/filesystem_entry.zig").FilesystemEntry;
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

    pub fn getRootEntry(self: *const Navigator, allocator: Allocator) !FilesystemEntry {
        const root_inode = try self.getRootInode();
        const root_name = try allocator.dupe(u8, "/");
        
        const EntryLayout = @import("../layout/entry_layout.zig").EntryLayout;
        const file_type = if (root_inode.isDirectory()) 
            EntryLayout.FILE_TYPES.DIR 
        else 
            EntryLayout.FILE_TYPES.REG_FILE;

        return FilesystemEntry{
            .name = root_name,
            .inode_number = 2,
            .size = root_inode.size(),
            .mode = root_inode.i_mode,
            .ext4_file_type = file_type,
        };
    }

    pub fn getEntry(self: *const Navigator, allocator: Allocator, path: []const u8) !FilesystemEntry {
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

        const EntryLayout = @import("../layout/entry_layout.zig").EntryLayout;
        const file_type = if (current_inode.isDirectory())
            EntryLayout.FILE_TYPES.DIR
        else if (current_inode.isRegularFile())
            EntryLayout.FILE_TYPES.REG_FILE
        else if (current_inode.isSymlink())
            EntryLayout.FILE_TYPES.SYMLINK
        else
            EntryLayout.FILE_TYPES.UNKNOWN;

        return FilesystemEntry{
            .name = current_name,
            .inode_number = current_inode_number,
            .size = current_inode.size(),
            .mode = current_inode.i_mode,
            .ext4_file_type = file_type,
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
            if (offset + @sizeOf(Entry) > dir_data.len) {
                break;
            }

            var dir_entry: Entry = undefined;
            const entry_bytes = std.mem.asBytes(&dir_entry);
            const available_bytes = @min(entry_bytes.len, dir_data.len - offset);
            @memcpy(entry_bytes[0..available_bytes], dir_data[offset .. offset + available_bytes]);

            if (!dir_entry.isValid() or dir_entry.getRecordLength() == 0) {
                break;
            }

            if (offset + dir_entry.getRecordLength() > dir_data.len) {
                break;
            }

            if (dir_entry.getInodeNumber() != 0) {
                const name = dir_entry.getName(dir_data, offset);
                if (std.mem.eql(u8, name, entry_name)) {
                    return dir_entry.getInodeNumber();
                }
            }

            offset = dir_entry.nextEntry(offset);
        }

        return errors.FileSystemError.EntryNotFound;
    }
};