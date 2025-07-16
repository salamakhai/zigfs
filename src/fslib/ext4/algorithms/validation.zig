//! Validation algorithms for EXT4 filesystem structures

const std = @import("std");

const validation_superblock = @import("validation_superblock.zig");
const validation_extents = @import("validation_extents.zig");
const validation_block_groups = @import("validation_block_groups.zig");
const validation_inodes = @import("validation_inodes.zig");

pub const ValidationResult = validation_superblock.ValidationResult;

// === Superblock ===
pub const validateSuperblockMagic = validation_superblock.validateMagic;
pub const validateBlockSize = validation_superblock.validateBlockSize;
pub const validateFilesystemCounts = validation_superblock.validateFilesystemCounts;
pub const validateBlockGroupLayout = validation_superblock.validateBlockGroupLayout;
pub const validateSuperblock = validation_superblock.validate;

// === Extent ===
pub const validateExtentHeaderMagic = validation_extents.validateHeaderMagic;
pub const validateExtentHeader = validation_extents.validateHeader;
pub const validateExtentEntry = validation_extents.validateExtentEntry;
pub const validateExtentIndex = validation_extents.validateExtentIndex;
pub const validateExtentDataBounds = validation_extents.validateExtentDataBounds;
pub const validateExtentTreeStructure = validation_extents.validateExtentTreeStructure;

// === Block Group ===
pub const validateBlockGroupNumber = validation_block_groups.validateBlockGroupNumber;
pub const validateBlockGroupDescriptor = validation_block_groups.validateDescriptor;
pub const validateBlockGroupDescriptorBounds = validation_block_groups.validateDescriptorBounds;
pub const validateBlockGroupFreeSpaceCounts = validation_block_groups.validateFreeSpaceCounts;
pub const validateBlockGroupMetadataBlocks = validation_block_groups.validateMetadataBlocks;

// === Inode ===
pub const validateInodeNumber = validation_inodes.validateInodeNumber;
pub const validateInodeMode = validation_inodes.validateInodeMode;
pub const validateInodeSize = validation_inodes.validateInodeSize;
pub const validateInodeTimestamps = validation_inodes.validateInodeTimestamps;
pub const validateInodeLinkCount = validation_inodes.validateInodeLinkCount;
pub const validateInodeBlockCount = validation_inodes.validateInodeBlockCount;
pub const validateInode = validation_inodes.validate;
