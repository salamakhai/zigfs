const std = @import("std");

/// EXT4 Inode Layout
/// 
/// This represents the raw on-disk structure of an EXT4 inode
/// The inode contains file/directory metadata and block addressing information
/// 
/// References
/// - Docs: https://docs.kernel.org/filesystems/ext4/dynamic.html#index-nodes
/// - Kernel: https://github.com/torvalds/linux/blob/master/fs/ext4/ext4.h
///
/// The inode structure containes:
/// - File type, permissions, and ownership
/// - File size and timestamps  
/// - Block allocation information (direct/indirect blocks or extents)
/// - Extended attributes and advanced features
pub const InodeLayout = extern struct {
    // Basic file metadata (0x00-0x1F)
    i_mode: u16,        // 0x00: File mode (type and permissions)
    i_uid: u16,         // 0x02: Owner user ID (low 16 bits)
    i_size_lo: u32,     // 0x04: File size in bytes (low 32 bits)
    i_atime: u32,       // 0x08: Access time (seconds since epoch)
    i_ctime: u32,       // 0x0C: Inode change time (seconds since epoch)
    i_mtime: u32,       // 0x10: Modification time (seconds since epoch)
    i_dtime: u32,       // 0x14: Deletion time (seconds since epoch)
    i_gid: u16,         // 0x18: Owner group ID (low 16 bits)
    i_links_count: u16, // 0x1A: Hard link count
    
    // Block allocation and flags (0x1C-0x27)
    i_blocks_lo: u32,   // 0x1C: Block count (low 32 bits, in 512-byte sectors)
    i_flags: u32,       // 0x20: Inode flags
    i_osd1: u32,        // 0x24: OS-dependent field 1 (usually unused)
    
    // Block addressing (0x28-0x67)
    /// Block addresses: can be direct/indirect blocks OR extent tree root
    /// Usage depends on EXT4_EXTENTS_FL flag in i_flags
    i_block: [N_BLOCKS]u32, // 0x28: Block pointers (60 bytes total)
    
    // Extended metadata (0x64-0x7F)
    i_generation: u32,  // 0x64: File version (for NFS)
    i_file_acl_lo: u32, // 0x68: Extended attributes block (low 32 bits)
    i_size_high: u32,   // 0x6C: File size high 32 bits (for large files)
    i_obso_faddr: u32,  // 0x70: Obsolete fragment address
    i_osd2: [12]u8,     // 0x74: OS-dependent field 2
    
    // Block addressing constants
    pub const NDIR_BLOCKS: u8 = 12;              // Number of direct block pointers
    pub const IND_BLOCK: u8 = NDIR_BLOCKS;       // Indirect block index
    pub const DIND_BLOCK: u8 = IND_BLOCK + 1;    // Double indirect block index
    pub const TIND_BLOCK: u8 = DIND_BLOCK + 1;   // Triple indirect block index
    pub const N_BLOCKS: u8 = TIND_BLOCK + 1;     // Total block pointer array size (15)
    
    // File type constants (upper 4 bits of i_mode)
    pub const FILE_TYPE_MASK: u16 = 0xF000;
    pub const FILE_TYPE_FIFO: u16 = 0x1000;      // FIFO
    pub const FILE_TYPE_CHARDEV: u16 = 0x2000;   // Character device
    pub const FILE_TYPE_DIR: u16 = 0x4000;       // Directory
    pub const FILE_TYPE_BLOCKDEV: u16 = 0x6000;  // Block device
    pub const FILE_TYPE_REGULAR: u16 = 0x8000;   // Regular file
    pub const FILE_TYPE_SYMLINK: u16 = 0xA000;   // Symbolic link
    pub const FILE_TYPE_SOCKET: u16 = 0xC000;    // Socket
    
    // Permission bit constants (lower 12 bits of i_mode)
    pub const PERM_MASK: u16 = 0x0FFF;            // All permission bits
    pub const S_ISUID: u16 = 0x0800;              // Set user ID on execution
    pub const S_ISGID: u16 = 0x0400;              // Set group ID on execution
    pub const S_ISVTX: u16 = 0x0200;              // Sticky bit
    pub const S_IRUSR: u16 = 0x0100;              // User read permission
    pub const S_IWUSR: u16 = 0x0080;              // User write permission
    pub const S_IXUSR: u16 = 0x0040;              // User execute permission
    pub const S_IRGRP: u16 = 0x0020;              // Group read permission
    pub const S_IWGRP: u16 = 0x0010;              // Group write permission
    pub const S_IXGRP: u16 = 0x0008;              // Group execute permission
    pub const S_IROTH: u16 = 0x0004;              // Other read permission
    pub const S_IWOTH: u16 = 0x0002;              // Other write permission
    pub const S_IXOTH: u16 = 0x0001;              // Other execute permission

    // Important inode flags
    pub const EXT4_EXTENTS_FL: u32 = 0x00080000;     // Inode uses extents
    pub const EXT4_INLINE_DATA_FL: u32 = 0x10000000; // Data stored in inode
    
    comptime {
        // Ensure the inode layout is the expected size
        // Standard EXT4 inode is 128 bytes minimum, but can be larger
        std.debug.assert(@sizeOf(InodeLayout) == 128);
    }
};