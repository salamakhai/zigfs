# FSLib - Filesystem Library
[_readme backlink_](../../README.md)

## Filesystem
### Structure

#### `filesystem.zig`
Allows filesystem creation from file, holds mounted filesystem as union

#### `root.zig`
Module exports

## Ext4

### Architecture

#### `/types/`
Wrappers around on-disk structures

#### `/disk/`
- On-disk data layouts structures
- Low-level disk operations

#### `/parsing/`
Parsing and validation algorithms

#### `/operations/`
High-level filesystem operations

#### `ext4.zig`
Public API for filesystem access

---

### References
- https://docs.kernel.org/filesystems/index.html
- https://github.com/torvalds/linux/tree/master/fs/ext4

- https://blogs.oracle.com/linux/post/understanding-ext4-disk-layout-part-1
- https://blogs.oracle.com/linux/post/understanding-ext4-disk-layout-part-2