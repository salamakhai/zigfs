const std = @import("std");

/// EXT4 Entry Layout
/// 
/// This represents the raw on-disk structure of EXT4 directory entries
/// Directory entries are variable-length records that map filenames to inodes
/// Directory entries are packed sequentially within directory data blocks
///
/// References
/// - Docs: https://docs.kernel.org/filesystems/ext4/dynamic.html#linear-classic-directories
/// - Kernel: https://github.com/torvalds/linux/blob/master/fs/ext4/ext4.h
///
/// Each entry contains:
/// - Inode number of the file/directory
/// - Variable-length filename
/// - File type information
/// - Padding to maintain alignment
pub const EntryLayout = extern struct {
    inode: u32,         // 0x00: Inode number (0 = unused entry)
    rec_len: u16,       // 0x04: Record length (including filename and padding)
    name_len: u8,       // 0x06: Filename length (0-255 characters)
    file_type: u8,      // 0x07: File type (EXT4_FT_* constants)

    // Total entry size = sizeof(DirectoryEntryLayout) + name_len + padding
    // Padding ensures rec_len is aligned to 4-byte boundaries
    
    /// File type constants (stored in file_type field)
    pub const FILE_TYPES = struct {
        pub const UNKNOWN: u8 = 0;     // Unknown file type
        pub const REG_FILE: u8 = 1;    // Regular file
        pub const DIR: u8 = 2;         // Directory
        pub const CHRDEV: u8 = 3;      // Character device
        pub const BLKDEV: u8 = 4;      // Block device
        pub const FIFO: u8 = 5;        // FIFO
        pub const SOCK: u8 = 6;        // Socket
        pub const SYMLINK: u8 = 7;     // Symbolic link
    };

    /// Directory entry constraints
    pub const CONSTRAINTS = struct {
        /// Maximum filename length
        pub const MAX_NAME_LEN: u8 = 255;
        /// Minimum record length (must fit the base structure)
        pub const MIN_REC_LEN: u16 = @sizeOf(EntryLayout);
        /// Record length alignment (must be multiple of 4)
        pub const REC_LEN_ALIGNMENT: u16 = 4;
    };

    pub const SPECIAL_ENTRIES = struct {
        /// Current directory entry name
        pub const CURRENT_DIR: []const u8 = ".";
        /// Parent directory entry name  
        pub const PARENT_DIR: []const u8 = "..";
    };

    comptime {
        std.debug.assert(@sizeOf(EntryLayout) == 8);
    }
};