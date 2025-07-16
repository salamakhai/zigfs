const std = @import("std");
const SuperblockLayout = @import("../disk/layout/superblock_layout.zig").SuperblockLayout;

// Types
pub const ValidationResult = struct {
    is_valid: bool,
    detected_block_size: u32,
    details: []const u8,

    pub fn success(block_size: u32) ValidationResult {
        return ValidationResult{
            .is_valid = true,
            .detected_block_size = block_size,
            .details = "Validations passed",
        };
    }

    pub fn failure(error_message: []const u8) ValidationResult {
        return ValidationResult{
            .is_valid = false,
            .detected_block_size = 0,
            .details = error_message,
        };
    }
};

// State
pub fn blockSize(superblock_layout: *const SuperblockLayout) u32 {
    const log_block_size = @as(u5, @truncate(superblock_layout.s_log_block_size));
    return SuperblockLayout.MIN_BLOCK_SIZE << log_block_size;
}

pub fn inodeSize(superblock_layout: *const SuperblockLayout) u32 {
    return if (superblock_layout.s_rev_level >= 1) 256 else 128;
}

pub fn totalBlockGroups(superblock_layout: *const SuperblockLayout) u32 {
    return (superblock_layout.s_blocks_count_lo + superblock_layout.s_blocks_per_group - 1) / superblock_layout.s_blocks_per_group;
}

// Validators
pub fn validateMagic(superblock_layout: *const SuperblockLayout) bool {
    return superblock_layout.s_magic == SuperblockLayout.MAGIC_NUMBER;
}

pub fn validateBlockSize(log_block_size: u32) bool {
    if (log_block_size > 16) {
        return false;
    }

    const block_size = SuperblockLayout.MIN_BLOCK_SIZE << @as(u5, @truncate(log_block_size));
    return block_size >= SuperblockLayout.MIN_BLOCK_SIZE and
        block_size <= SuperblockLayout.MAX_BLOCK_SIZE;
}

pub fn validateFilesystemCounts(superblock_layout: *const SuperblockLayout) bool {
    if (superblock_layout.s_blocks_count_lo == 0) return false;
    if (superblock_layout.s_inodes_count == 0) return false;
    if (superblock_layout.s_r_blocks_count_lo > superblock_layout.s_blocks_count_lo) return false;

    return true;
}

pub fn validateBlockGroupLayout(superblock_layout: *const SuperblockLayout) bool {
    if (superblock_layout.s_blocks_per_group == 0) return false;
    if (superblock_layout.s_inodes_per_group == 0) return false;

    const total_blocks = superblock_layout.s_blocks_count_lo;
    const blocks_per_group = superblock_layout.s_blocks_per_group;
    const num_block_groups = (total_blocks + blocks_per_group - 1) / blocks_per_group;

    const expected_min_inodes = num_block_groups;
    const expected_max_inodes = num_block_groups * superblock_layout.s_inodes_per_group;

    return superblock_layout.s_inodes_count >= expected_min_inodes and
        superblock_layout.s_inodes_count <= expected_max_inodes;
}

pub fn validate(superblock_layout: *const SuperblockLayout) ValidationResult {
    if (!validateMagic(superblock_layout)) {
        return ValidationResult.failure("Invalid magic number");
    }

    if (!validateBlockSize(superblock_layout.s_log_block_size)) {
        return ValidationResult.failure("Invalid block size");
    }

    if (!validateFilesystemCounts(superblock_layout)) {
        return ValidationResult.failure("Invalid filesystem counts");
    }

    if (!validateBlockGroupLayout(superblock_layout)) {
        return ValidationResult.failure("Invalid block group layout");
    }

    const block_size = SuperblockLayout.MIN_BLOCK_SIZE << @as(u5, @truncate(superblock_layout.s_log_block_size));

    return ValidationResult.success(block_size);
}
