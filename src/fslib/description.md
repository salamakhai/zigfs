[_readme backlink_](../../README.md)

### /algorithms
- filesystem's low level algorithms on layouts;

### /layout 
- low level physical representations of a ext4 structures; 

### /structures 
- wrappers for layout data, contains functions data convertion
and higher level data representation;
- can use algorithms

### /operations
- can use layouts, structures,
- logic for high level operations on ext4 filesystem,
- public functions should not expose internal layouts,
- operate publicly only on structures

### ext4_fs
- main filesystem representation, consists of structures and operations,
- contains public api for filesystem operations

### ext4_impl 
- Converter ext4_fs into generic filesystem