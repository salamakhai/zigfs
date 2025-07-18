const std = @import("std");
const Allocator = std.mem.Allocator;
const Entry = @import("entry.zig").Entry;
const EntryLayout = @import("../disk/layout.zig").EntryLayout;

pub const EntryContext = struct {
    // Fields
    entries: []Entry,
    directory_data: []u8,
    allocator: Allocator,

    // Lifecycle
    pub fn init(allocator: Allocator, entries: []Entry, directory_data: []u8) EntryContext {
        return EntryContext{
            .entries = entries,
            .directory_data = directory_data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntryContext) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.directory_data);
    }

    // Public
    pub fn getEntryNameByIndex(self: *const EntryContext, index: usize) []const u8 {
        if (index >= self.entries.len) {
            return &[_]u8{};
        }

        const entry = &self.entries[index];
        const offset = self.calculateEntryOffset(index);

        const name_start = offset + @sizeOf(EntryLayout);
        const name_end = name_start + entry.nameLength();

        if (name_end <= self.directory_data.len) {
            return self.directory_data[name_start..name_end];
        }

        return &[_]u8{};
    }

    pub fn entryNameEql(self: *const EntryContext, index: usize, name: []const u8) bool {
        return std.mem.eql(u8, self.getEntryNameByIndex(index), name);
    }

    // Private
    fn calculateEntryOffset(self: *const EntryContext, index: usize) usize {
        var offset: usize = 0;
        for (0..index) |i| {
            offset += self.entries[i].recordLength();
        }
        return offset;
    }
};
