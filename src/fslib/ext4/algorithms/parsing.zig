//! Parsing algorithms for EXT4 filesystem layouts

const std = @import("std");

const parsing_superblock = @import("parsing_superblock.zig");
const parsing_extents = @import("parsing_extents.zig");
const parsing_block_groups = @import("parsing_block_groups.zig");
const parsing_inodes = @import("parsing_inodes.zig");

const Allocator = std.mem.Allocator;

// === Types ===
pub const ExtentMapping = parsing_extents.ExtentMapping;

// === Superblock ===
pub const blockSize = parsing_superblock.blockSize;
pub const inodeSize = parsing_superblock.inodeSize;
pub const totalBlockGroups = parsing_superblock.totalBlockGroups;

// === Extent ===
pub const parseExtentHeader = parsing_extents.parseExtentHeader;
pub const isExtentLeaf = parsing_extents.isExtentLeaf;
pub const extractExtentMappings = parsing_extents.extractExtentMappings;
pub const extractExtentIndices = parsing_extents.extractExtentIndices;

// === BlockGroup ===
pub const parseBlockGroupDescriptor = parsing_block_groups.parseBlockGroupDescriptor;

// === Inode ===
pub const extractInodeBlockData = parsing_inodes.extractInodeBlockData;
