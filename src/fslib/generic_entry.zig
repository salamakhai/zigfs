const std = @import("std");

pub const EntryType = enum {
    unknown,
    file,
    directory,
    symlink,
    character_device,
    block_device,
    fifo,
    socket,
};

/// Optional metadata that may be unsupported
pub const EntryMetadata = struct {
    /// File size in bytes
    size: ?u64,
    /// UNIX-style permissions
    mode: ?u16,
    /// Filesystem-specific identifier (inode number, file ID)
    filesystem_id: ?u64,
};

pub const GenericEntry = struct {
    // Variables
    name: []const u8,
    entry_type: EntryType,
    metadata: EntryMetadata,

    // Public
    pub fn isFile(self: *const GenericEntry) bool {
        return self.entry_type == .file;
    }

    pub fn isDirectory(self: *const GenericEntry) bool {
        return self.entry_type == .directory;
    }
    
    pub fn isSymlink(self: *const GenericEntry) bool {
        return self.entry_type == .symlink;
    }
    
    pub fn getSize(self: *const GenericEntry) ?u64 {
        return self.metadata.size;
    }
    
    pub fn getMode(self: *const GenericEntry) ?u16 {
        return self.metadata.mode;
    }
    
    pub fn getFilesystemId(self: *const GenericEntry) ?u64 {
        return self.metadata.filesystem_id;
    }
};
