const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;

pub const Navigator = struct {
    allocator: Allocator,
    reader: *const Reader,

    pub fn init(allocator: Allocator, reader: *const Reader) Navigator {
        return Navigator{
            .allocator = allocator,
            .reader = reader,
        };
    }

    // Public
    pub fn getRootInode(self: *const Navigator) !Inode {
        return self.reader.readInode(2);
    }

    pub fn getRootEntry(self: *const Navigator) !Entry {
        _ = self;

    }

    pub fn getEntry(self: *const Navigator, path: []const u8) !Entry {
        _ = self;
        _ = path;

    }

    // Private
    fn findEntryInDirectory(self: *const Navigator, inode: *const Inode, entry_name: []const u8) !u32 {
        _ = self;
        _ = inode;
        _ = entry_name;

    }
};