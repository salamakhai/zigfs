const std = @import("std");
const DirectoryEntryLayout = @import("../layout/directory_entry_layout.zig").DirectoryEntryLayout;

/// Algorithms for traversing EXT4 directory structures
/// 
/// Implement directory entry parsing and validation without IO.
/// Parse directory data blocks to extract filenames, inode numbers, and
/// file type information.
///
/// EXT4 Directory Structure:
/// - Directory data is stored in one or more blocks
/// - Each block contains variable-length directory entries
/// - Entries are packed sequentially with padding for alignment
/// - Each entry has: inode number, record length, name length, file type, name
/// - Special entries: "." (current) and ".." (parent) directories
///
/// References:
/// - https://docs.kernel.org/filesystems/ext4/dynamic.html#linear-classic-directories
pub const DirectoryTraversalAlgorithm = struct {
    
    /// Parsed directory entry with all information extracted
    pub const ParsedDirectoryEntry = struct {
        /// Inode number (0 = deleted entry)
        inode_number: u32,
        /// Entry name (owned by caller)
        name: []const u8,
        /// File type from directory entry
        file_type: DirectoryEntryLayout.FILE_TYPES,
        /// Total record length including padding
        record_length: u16,
        /// Is this entry is valid
        is_valid: bool,
        /// Is this a special entry
        is_special: bool,
        
        /// Check if this is the current directory entry (".")
        pub fn isCurrentDirectory(self: ParsedDirectoryEntry) bool {
            return std.mem.eql(u8, self.name, DirectoryEntryLayout.SPECIAL_ENTRIES.CURRENT_DIR);
        }
        
        /// Check if this is the parent directory entry ("..")
        pub fn isParentDirectory(self: ParsedDirectoryEntry) bool {
            return std.mem.eql(u8, self.name, DirectoryEntryLayout.SPECIAL_ENTRIES.PARENT_DIR);
        }
    };
    
    /// Iterator for traversing directory entries in a data block
    pub const DirectoryIterator = struct {
        data: []const u8,
        offset: usize,
        
        pub fn init(directory_data: []const u8) DirectoryIterator {
            return DirectoryIterator{
                .data = directory_data,
                .offset = 0,
            };
        }
        
        /// Get next directory entry or null if no more entries
        pub fn next(self: *DirectoryIterator, allocator: std.mem.Allocator) ?ParsedDirectoryEntry {
            while (self.offset < self.data.len) {
                const entry = parseDirectoryEntryAt(self.data, self.offset, allocator) catch {
                    // Skip invalid entries and continue
                    self.offset += DirectoryEntryLayout.CONSTRAINTS.MIN_REC_LEN;
                    continue;
                };
                
                if (entry) |parsed_entry| {
                    self.offset += parsed_entry.record_length;
                    return parsed_entry;
                }
                
                // No valid entry found end iteration
                break;
            }
            
            return null;
        }
    };
    
    /// Parse all directory entries from a directory data block
    pub fn parseDirectoryEntries(
        directory_data: []const u8,
        allocator: std.mem.Allocator,
    ) ![]ParsedDirectoryEntry {
        var entries = std.ArrayList(ParsedDirectoryEntry).init(allocator);
        defer entries.deinit();
        
        var iterator = DirectoryIterator.init(directory_data);
        while (iterator.next(allocator)) |entry| {
            if (entry.is_valid and entry.inode_number != 0) {
                try entries.append(entry);
            }
        }
        
        return entries.toOwnedSlice();
    }
    
    /// Parse a single directory entry at a specific offset
    pub fn parseDirectoryEntryAt(
        directory_data: []const u8,
        offset: usize,
        allocator: std.mem.Allocator,
    ) !?ParsedDirectoryEntry {
        // Ensure is enough data for the basic directory entry structure
        if (offset + @sizeOf(DirectoryEntryLayout) > directory_data.len) {
            return null;
        }
        
        // Parse the directory entry header
        const entry_layout = @as(*const DirectoryEntryLayout, @ptrCast(@alignCast(
            &directory_data[offset]
        )));
        
        // Validate basic entry structure
        if (!isValidDirectoryEntry(entry_layout, directory_data.len - offset)) {
            return error.InvalidDirectoryEntry;
        }
        
        // Extract the filename
        const name_start = offset + @sizeOf(DirectoryEntryLayout);
        const name_end = name_start + entry_layout.name_len;
        
        if (name_end > directory_data.len) {
            return error.NameTruncated;
        }
        
        const name = directory_data[name_start..name_end];
        const owned_name = try allocator.dupe(u8, name);
        
        // Determine if this is a special entry
        const is_special = isSpecialDirectoryEntry(name);
        
        return ParsedDirectoryEntry{
            .inode_number = entry_layout.inode,
            .name = owned_name,
            .file_type = entry_layout.file_type,
            .record_length = entry_layout.rec_len,
            .is_valid = true,
            .is_special = is_special,
        };
    }
    
    /// Find a specific directory entry by name
    pub fn findDirectoryEntry(
        directory_data: []const u8,
        target_name: []const u8,
        allocator: std.mem.Allocator,
    ) !?ParsedDirectoryEntry {
        var iterator = DirectoryIterator.init(directory_data);
        
        while (iterator.next(allocator)) |entry| {
            if (entry.is_valid and std.mem.eql(u8, entry.name, target_name)) {
                return entry;
            }
            // Note: This is simplified for the algorithm extraction
        }
        
        return null;
    }

    pub fn isValidDirectoryEntry(
        entry: *const DirectoryEntryLayout,
        available_data: usize,
    ) bool {
        // Check basic constraints
        if (entry.rec_len < DirectoryEntryLayout.CONSTRAINTS.MIN_REC_LEN) {
            return false;
        }
        
        if (entry.name_len > DirectoryEntryLayout.CONSTRAINTS.MAX_NAME_LEN) {
            return false;
        }
        
        // Record length must be aligned
        if (entry.rec_len % DirectoryEntryLayout.CONSTRAINTS.REC_LEN_ALIGNMENT != 0) {
            return false;
        }
        
        // Entry must fit within available data
        if (entry.rec_len > available_data) {
            return false;
        }
        
        // Name must fit within record length
        const name_space_needed = @sizeOf(DirectoryEntryLayout) + entry.name_len;
        if (name_space_needed > entry.rec_len) {
            return false;
        }
        
        return true;
    }

    pub fn isSpecialDirectoryEntry(name: []const u8) bool {
        return std.mem.eql(u8, name, DirectoryEntryLayout.SPECIAL_ENTRIES.CURRENT_DIR) or
               std.mem.eql(u8, name, DirectoryEntryLayout.SPECIAL_ENTRIES.PARENT_DIR);
    }

    pub fn convertFileType(ext4_file_type: u8) FileType {
        return switch (ext4_file_type) {
            DirectoryEntryLayout.FILE_TYPES.REG_FILE => .regular_file,
            DirectoryEntryLayout.FILE_TYPES.DIR => .directory,
            DirectoryEntryLayout.FILE_TYPES.SYMLINK => .symbolic_link,
            DirectoryEntryLayout.FILE_TYPES.CHRDEV => .character_device,
            DirectoryEntryLayout.FILE_TYPES.BLKDEV => .block_device,
            DirectoryEntryLayout.FILE_TYPES.FIFO => .fifo,
            DirectoryEntryLayout.FILE_TYPES.SOCK => .socket,
            else => .unknown,
        };
    }
    
    /// Generic file type enum
    pub const FileType = enum {
        unknown,
        regular_file,
        directory,
        symbolic_link,
        character_device,
        block_device,
        fifo,
        socket,
    };

    pub fn calculateNextEntryOffset(current_offset: usize, record_length: u16) usize {
        return current_offset + record_length;
    }

    pub fn validateDirectoryData(directory_data: []const u8) bool {
        var offset: usize = 0;
        
        while (offset < directory_data.len) {
            if (offset + @sizeOf(DirectoryEntryLayout) > directory_data.len) {
                return false;
            }
            
            const entry = @as(
                *const DirectoryEntryLayout,
                @ptrCast(@alignCast(&directory_data[offset]))
            );
            
            if (!isValidDirectoryEntry(entry, directory_data.len - offset)) {
                return false;
            }
            
            // Zero record length indicates end of directory
            if (entry.rec_len == 0) {
                return false;
            }
            
            offset += entry.rec_len;
        }
        
        return true;
    }
};