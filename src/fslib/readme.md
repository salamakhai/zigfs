# FSLib - Filesystem Library
[_readme backlink_](../../README.md)

## Filesystem
### Structure

#### `filesystem.zig`
Allows filesystem creation from file, holds mounted filesystem as union

#### `root.zig`
Module exports

## Ext4
### Layout

```
Block 0: Boot block (unused)
Block 1: Superblock
  ─ Magic number (0xEF53) for detection
  ─ Block/inode counts and configuration  
  ─ Feature flags and validation data
Block >=2: Block group descriptors
Block Groups:
  ─ Block bitmap (tracks allocated blocks)
  ─ Inode bitmap (tracks allocated inodes)
  ─ Inode table (array of inode structures)
  ─ Data blocks (file and directory content)

Data Flow:
Directory Entry → Inode (metadata + extents) → Data Blocks
```

### Structure

#### `/algorithms/`
Low level algorithms, operates on layouts

#### `/layout/`
Raw on-disk ext4 structures definitions (extern/packed structs)

#### `/structures/` 
High-level wrappers around layouts

#### `/operations/`
Filesystem operations using structures and layouts

#### `ext4_fs.zig`
Main filesystem interface - coordinates all operations  
Public API for filesystem access

---

### References
- https://docs.kernel.org/filesystems/index.html
- https://github.com/torvalds/linux/tree/master/fs/ext4
- https://blogs.oracle.com/linux/post/understanding-ext4-disk-layout-part-1
