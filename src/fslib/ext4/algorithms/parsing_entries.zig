const std = @import("std");
const Allocator = std.mem.Allocator;
const EntryLayout = @import("../layout/entry_layout.zig").EntryLayout;

const validateEntry = @import("validation.zig").validateEntry;

// === Types ===
pub const ParsedEntry = struct {
    layout: EntryLayout,
    name: []const u8,
};

// === Public ===
pub fn parseDirectoryEntries(directory_data: []const u8, allocator: Allocator) ![]ParsedEntry {
    var entries = std.ArrayList(ParsedEntry).init(allocator);
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
            const name = try allocator.dupe(u8, directory_data[name_start..name_end]);
            const entry = ParsedEntry{
                .layout = entry_layout.*,
                .name = name,
            };
            try entries.append(entry);
        }

        offset += entry_layout.rec_len;
    }

    return entries.toOwnedSlice();
}
