const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("../structures/entry.zig").Entry;
const Inode = @import("../structures/inode.zig").Inode;
const Reader = @import("reader.zig").Reader;
const Error = @import("../ext4_error.zig").Ext4Error;

pub const Lister = struct {
    allocator: Allocator,
    reader: *const Reader,

    pub fn init(allocator: Allocator, reader: *const Reader) Lister {
        return Lister{
            .allocator = allocator,
            .reader = reader,
        };
    }

    pub fn listDirectory(self: *const Lister, entry: Entry) ![]Entry {
        _ = self;

        const inode_number = entry.getInodeNumber();
        _ = inode_number;

        // Read directory inode

        // Read directory data

        // Use Entry structure's algorithm to parse directory entries

        // Algorithms should operate with layouts

        // Convert layouts to entries

        // return entries
    }
};
