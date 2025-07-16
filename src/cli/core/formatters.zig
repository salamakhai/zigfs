const std = @import("std");

pub fn formatFileSize(size: u64, buffer: []u8) ![]const u8 {
    const units = [_][]const u8{ "B", "KiB", "MiB", "GiB", "TiB" };
    var value: f64 = @floatFromInt(size);
    var unit_index: usize = 0;

    if (!std.math.isFinite(value)) {
        return std.fmt.bufPrint(buffer, "Invalid size", .{});
    }

    while (value >= 1024.0 and unit_index < units.len - 1) : (unit_index += 1) {
        value /= 1024.0;

        if (std.math.isInf(value) or std.math.isNan(value)) {
            return std.fmt.bufPrint(buffer, "Invalid size", .{});
        }
    }

    if (unit_index == 0) {
        return std.fmt.bufPrint(buffer, "{d} {s}", .{ @as(u64, @intFromFloat(value)), units[unit_index] });
    } else {
        return std.fmt.bufPrint(buffer, "{d:.1} {s}", .{ value, units[unit_index] });
    }
}

test "formatFileSize" {
    var buffer: [32]u8 = undefined;

    // Test bytes
    try std.testing.expectEqualStrings(
        "0 B",
        try formatFileSize(0, &buffer),
    );
    try std.testing.expectEqualStrings(
        "1023 B",
        try formatFileSize(1023, &buffer),
    );

    // Test GiB
    try std.testing.expectEqualStrings(
        "1.0 GiB",
        try formatFileSize(1024 * 1024 * 1024, &buffer),
    );

    // Test TiB
    try std.testing.expectEqualStrings(
        "1.0 TiB",
        try formatFileSize(1024 * 1024 * 1024 * 1024, &buffer),
    );
    try std.testing.expectEqualStrings(
        "1048576.0 TiB",
        try formatFileSize(1024 * 1024 * 1024 * 1024 * 1024 * 1024, &buffer),
    );
}
