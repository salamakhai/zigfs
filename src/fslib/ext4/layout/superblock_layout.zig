const std = @import("std");

/// EXT4 Superblock Layout
///
/// This represents the on-disk structure of an EXT4 superblock.
/// Total size: 1024 bytes, little-endian encoding.
///
/// References
/// - Docs: https://docs.kernel.org/filesystems/ext4/globals.html
/// - Kernel: https://github.com/torvalds/linux/blob/master/fs/ext4/ext4.h
///
/// The superblock contains filesystem metadata:
/// - Filesystem size and block configuration
/// - Inode and block allocation counters
/// - Feature flags and compatibility information
/// - Timestamps and mount statistics
/// - Journaling configuration (not implemented)
pub const SuperblockLayout = packed struct {
    // Basic filesystem counters (0x00-0x13)
    s_inodes_count: u32,        // 0x00: Total inode count
    s_blocks_count_lo: u32,     // 0x04: Total block count (lower 32-bits)
    s_r_blocks_count_lo: u32,   // 0x08: Reserved block count (lower 32-bits)
    s_free_blocks_count_lo: u32,// 0x0C: Free block count (lower 32-bits)
    s_free_inodes_count: u32,   // 0x10: Free inode count

    // Block and group configuration (0x14-0x2B)
    s_first_data_block: u32,    // 0x14: First data block
    s_log_block_size: u32,      // 0x18: Block size = 1024 << s_log_block_size
    s_log_cluster_size: u32,    // 0x1C: Cluster size = 1024 << s_log_cluster_size
    s_blocks_per_group: u32,    // 0x20: Blocks per block group
    s_clusters_per_group: u32,  // 0x24: Clusters per block group
    s_inodes_per_group: u32,    // 0x28: Inodes per block group

    // Timestamps and mount information (0x2C-0x37)
    s_mtime: u32,               // 0x2C: Mount time (seconds since epoch)
    s_wtime: u32,               // 0x30: Write time (seconds since epoch)
    s_mnt_count: u16,           // 0x34: Number of times mounted
    s_max_mnt_count: i16,       // 0x36: Maximum mount count before fsck

    // Filesystem identification (0x38-0x3F)
    s_magic: u16,               // 0x38: Magic signature (0xEF53)
    s_state: u16,               // 0x3A: File system state flags
    s_errors: u16,              // 0x3C: Behavior when detecting errors
    s_minor_rev_level: u16,     // 0x3E: Minor revision level

    // Additional metadata (0x40-0x4F)
    s_lastcheck: u32,           // 0x40: Time of last check (seconds since epoch)
    s_checkinterval: u32,       // 0x44: Maximum time between checks
    s_creator_os: u32,          // 0x48: OS that created the filesystem
    s_rev_level: u32,           // 0x4C: Revision level

    // Extended attributes and features (0x50-0x6B)
    s_def_resuid: u16,          // 0x50: Default reserved user ID
    s_def_resgid: u16,          // 0x52: Default reserved group ID
    s_first_ino: u32,           // 0x54: First non-reserved inode
    s_inode_size: u16,          // 0x58: Size of inode structure
    s_block_group_nr: u16,      // 0x5A: Block group this superblock belongs to
    s_feature_compat: u32,      // 0x5C: Compatible feature flags
    s_feature_incompat: u32,    // 0x60: Incompatible feature flags
    s_feature_ro_compat: u32,   // 0x64: Read-only compatible feature flags

    // EXT4 Constants
    pub const MAGIC_NUMBER: u16 = 0xEF53;
    pub const OFFSET_IN_DEVICE: u64 = 1024;
    pub const MIN_BLOCK_SIZE: u32 = 1024;
    pub const MAX_BLOCK_SIZE: u32 = 65536; // 64KB
    pub const DEFAULT_BLOCK_SIZE: u32 = 4096;

    // Note: This struct only includes the most essential fields for basic filesystem operations.
    // The full superblock contains additional fields up to offset 1024, for example:
    // - Journal configuration (s_journal_inum, s_journal_dev, etc.)
    // - UUID and volume labels
    // - Extended feature flags
    // - Etc...
};