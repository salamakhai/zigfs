# ZIGFS

A filesystem toolset written in Zig  
[Github link](https://github.com/isalamaha/zigfs.git)

## Modules Documentation

[/fslib](src/fslib/readme.md)  
[/cli](src/cli/readme.md)  

## Test
Binary and test image are included  

Executable location:
```
zig-out/bin/zigfs 
```
Sample images locations:
```
test/ext4_test.img
```
**Test browse command:**
```sh
./zig-out/bin/zigfs browse test/ext4_test.img 
```

---  

## Building

[Zig installation guide](https://zig.guide/getting-started/installation/)

```sh
cd zigfs
```  
```sh
zig build
```
**Ensure the binary is executable:**  
```sh
chmod +x zig-out/bin/zigfs
```
**Run the executable:**  
```sh
./zig-out/bin/zigfs
```

## Examples

### Browser example session
```
 % ./zig-out/bin/zigfs browse test/ext4_test.img 
Opening file: test/ext4_test.img...
Filesystem detected and mounted successfully

Available commands:
  help         - Show this help message
  info         - Display filesystem information
  ls           - List directory contents
  cd           - Change current working directory
  cat          - Extract data from a file
  exit/quit    - Exit the browser

ext4_test ~/ % info
Filesystem information:
  Type: ext4
  Block size: 4096 bytes
  Total blocks: 16384
  Free blocks: 14298
  Total size: 67108864 bytes
  Free size: 58564608 bytes
  Total inodes: 16384
  Free inodes: 16352
  Blocks per group: 32768
  Inodes per group: 16384
ext4_test ~/ % ls
Name                      Type       Permissions     Size
--------------------------------------------------------------
.                         dir        drwxr-xr-x      4.0 KB
..                        dir        drwxr-xr-x      4.0 KB
lost+found                dir        drwx------      16.0 KB
home                      dir        drwxr-xr-x      4.0 KB
etc                       dir        drwxr-xr-x      4.0 KB
var                       dir        drwxr-xr-x      4.0 KB
usr                       dir        drwxr-xr-x      4.0 KB
tmp                       dir        drwxr-xr-x      4.0 KB
boot                      dir        drwxr-xr-x      4.0 KB
test_data                 dir        drwxr-xr-x      4.0 KB
hello.txt                 file       -rw-r--r--      14 B

Total: 11 entries
ext4_test ~/ % cd test_data/code
ext4_test ~/test_data/code % ls
Name                      Type       Permissions     Size
--------------------------------------------------------------
.                         dir        drwxr-xr-x      4.0 KB
..                        dir        drwxr-xr-x      4.0 KB
hello.py                  file       -rw-r--r--      28 B
hello.c                   file       -rw-r--r--      74 B

Total: 4 entries
ext4_test ~/test_data/code % cat hello.c
Content of 'hello.c' (74 bytes):
#include <stdio.h>

int main() {
    printf("hello c!\n");
    return 0;
}
ext4_test ~/test_data/code % exit

```
