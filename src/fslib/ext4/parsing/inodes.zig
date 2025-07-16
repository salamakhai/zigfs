const std = @import("std");
const InodeLayout = @import("../disk/layout.zig").InodeLayout;

// State
fn isDirectory(inode_layout: *const InodeLayout) bool {
    const mode = inode_layout.i_mode;
    return (mode & 0xF000) == 0x4000;
}

fn isRegularFile(inode_layout: *const InodeLayout) bool {
    const mode = inode_layout.i_mode;
    return (mode & 0xF000) == 0x8000;
}

fn hasData(inode_layout: *const InodeLayout) bool {
    return inode_layout.i_size_lo > 0 or inode_layout.i_size_hi > 0;
}

// Parsers
pub fn parseInodeBlockData(inode_layout: *const InodeLayout) []const u8 {
    return std.mem.asBytes(&inode_layout.i_block);
}

// Validators
pub fn validateInodeNumber(inode_number: u32, total_inodes: u32) bool {
    return inode_number > 0 and inode_number <= total_inodes;
}

pub fn validateInodeMode(inode_layout: *const InodeLayout) bool {
    const mode = inode_layout.i_mode;

    const file_type_mask = 0xF000;
    const file_type = mode & file_type_mask;

    return file_type != 0;
}

pub fn validateInodeSize(inode_layout: *const InodeLayout) bool {
    const size_lo = inode_layout.i_size_lo;
    const size_hi = inode_layout.i_size_hi;

    if (size_lo == 0xFFFFFFFF and size_hi == 0xFFFFFFFF) {
        return false;
    }

    return true;
}

pub fn validateInodeTimestamps(inode_layout: *const InodeLayout) bool {
    if (inode_layout.i_atime == 0 and inode_layout.i_mtime == 0 and inode_layout.i_ctime == 0) {
        return false;
    }

    return true;
}

pub fn validateInodeLinkCount(inode_layout: *const InodeLayout) bool {
    const links_count = inode_layout.i_links_count;

    if (isDirectory(inode_layout) and links_count < 2) {
        return false;
    }

    if (isRegularFile(inode_layout) and links_count == 0) {
        return false;
    }

    return true;
}

pub fn validateInodeBlockCount(inode_layout: *const InodeLayout) bool {
    const blocks_lo = inode_layout.i_blocks_lo;

    if (hasData(inode_layout) and blocks_lo == 0) {
        return false;
    }

    return true;
}

pub fn validate(inode_layout: *const InodeLayout) bool {
    if (!validateInodeMode(inode_layout)) return false;
    if (!validateInodeSize(inode_layout)) return false;
    if (!validateInodeTimestamps(inode_layout)) return false;
    if (!validateInodeLinkCount(inode_layout)) return false;
    if (!validateInodeBlockCount(inode_layout)) return false;

    return true;
}
