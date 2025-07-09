[_readme backlink_](../../README.md)

# FSLib - Filesystem Library

## EXT4 Layout Concepts

```
Directory Entry (filename + inode) -> Inode (size, block pointers) -> Data Blocks

Structure:
- Superblock: filesystem metadata (block size, inode count, etc.)
- Block Groups: organize inodes and data blocks
- Directory Entries: stored in directory data blocks, contain filename + inode number
- Inodes: contain file metadata and block allocation info (direct blocks or extents)
- Data Blocks: contain actual content
```

## Code Structure

### `/layout/`
Raw on-disk structure definitions (extern structs)

### `/structures/` 
High-level wrappers around layouts

### `/operations/`
Filesystem operations using structures and layouts

### `ext4_fs.zig`
Main filesystem interface - coordinates all operations
- Public API for filesystem access
- Manages lifecycle of operations modules

### `ext4_impl.zig`
Adapter between EXT4 filesystem and generic filesystem interface
- Converts EXT4 types to generic types
- Implements generic filesystem operations