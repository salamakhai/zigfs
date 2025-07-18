const std = @import("std");
const Allocator = std.mem.Allocator;
const EntryLayout = @import("../disk/layout.zig").EntryLayout;
const Entry = @import("../types/entry.zig").Entry;

// Parsers
pub fn parseDirectoryEntries(directory_data: []const u8, allocator: Allocator) ![]Entry {
    var entries = std.ArrayList(Entry).init(allocator);
    defer entries.deinit();

    var offset: usize = 0;

    while (offset < directory_data.len) {
        if (offset + @sizeOf(EntryLayout) > directory_data.len) {
            break;
        }

        const entry_layout = @as(*const EntryLayout, @ptrCast(@alignCast(&directory_data[offset])));

        if (!validateEntry(entry_layout, directory_data.len - offset)) {
            break;
        }

        if (entry_layout.inode == 0) {
            offset += entry_layout.rec_len;
            continue;
        }

        const name_start = offset + @sizeOf(EntryLayout);
        const name_end = name_start + entry_layout.name_len;

        if (name_end <= directory_data.len) {
            const entry = Entry{
                .layout = entry_layout.*,
            };
            try entries.append(entry);
        }

        offset += entry_layout.rec_len;
    }

    return entries.toOwnedSlice();
}

// Validators
pub fn validateEntry(entry: *const EntryLayout, available_data: usize) bool {
    if (entry.rec_len < @sizeOf(EntryLayout)) {
        return false;
    }

    if (entry.name_len > EntryLayout.CONSTRAINTS.MAX_NAME_LEN) {
        return false;
    }

    if (entry.rec_len % EntryLayout.CONSTRAINTS.REC_LEN_ALIGNMENT != 0) {
        return false;
    }

    if (entry.rec_len > available_data) {
        return false;
    }

    const name_space_needed = @sizeOf(EntryLayout) + entry.name_len;
    if (name_space_needed > entry.rec_len) {
        return false;
    }

    return true;
}
