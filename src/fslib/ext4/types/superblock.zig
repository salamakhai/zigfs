const std = @import("std");
const SuperblockLayout = @import("../disk/layout.zig").SuperblockLayout;

pub const Superblock = struct {
    // Fields
    layout: SuperblockLayout,

    // Lifecycle
    pub fn detect(file: std.fs.File) bool {
        file.seekTo(SuperblockLayout.OFFSET_IN_DEVICE + @offsetOf(SuperblockLayout, "s_magic")) catch {
            return false;
        };

        var magic_bytes: u16 = undefined;
        const bytes_read = file.readAll(std.mem.asBytes(&magic_bytes)) catch {
            return false;
        };

        return bytes_read == @sizeOf(u16) and magic_bytes == SuperblockLayout.MAGIC_NUMBER;
    }

    pub fn create(file: std.fs.File) !Superblock {
        try file.seekTo(SuperblockLayout.OFFSET_IN_DEVICE);

        var layout: SuperblockLayout = undefined;
        const read_bytes = try file.read(std.mem.asBytes(&layout));

        if (read_bytes < @sizeOf(SuperblockLayout)) {
            return error.ReadError;
        }

        return Superblock{
            .layout = layout,
        };
    }

    // Public
    pub fn blockSize(self: *const Superblock) u32 {
        return @as(u32, 1024) << @intCast(self.layout.s_log_block_size);
    }

    pub fn magic(self: *const Superblock) u16 {
        return self.layout.s_magic;
    }

    pub fn blocksCount(self: *const Superblock) u32 {
        return self.layout.s_blocks_count_lo;
    }

    pub fn inodesCount(self: *const Superblock) u32 {
        return self.layout.s_inodes_count;
    }

    pub fn blocksPerGroup(self: *const Superblock) u32 {
        return self.layout.s_blocks_per_group;
    }

    pub fn inodesPerGroup(self: *const Superblock) u32 {
        return self.layout.s_inodes_per_group;
    }
};
