//! Entries validation algorithms for EXT4 filesystem

const std = @import("std");
const Allocator = std.mem.Allocator;
const EntryLayout = @import("../layout/entry_layout.zig").EntryLayout;

// === Public ===
pub fn validate(entry: *const EntryLayout, available_data: usize) bool {
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
