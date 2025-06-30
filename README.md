# ZIGFS

A filesystem toolset written in Zig  
[Github link](https://github.com/isalamaha/zigfs.git)


## TEST: Binary and test image included

```sh
./zig-out/bin/zigfs browse test/ext4_test.img 
```

---  

## Building

```sh
cd zigfs
```  
```sh
zig build
```
**Ensure the binary is executable**  
```sh
chmod +x zig-out/bin/zigfs
```
**Run the executable**  
```sh
./zig-out/bin/zigfs
```

## Examples

### Main help menu
```sh
 % ./zig-out/bin/zigfs

Available commands:
  help         
  info         Display detailed information about a filesystem image
  ls           List directory contents
  cat          Extract data from a file
  browse       Interactive FileSystem browser
  
```

### Browser example session
```sh
 % ./zig-out/bin/zigfs browse test/ext4_test.img
Opening file: test/ext4_test.img...
Filesystem detected and mounted successfully

Available commands:
  help         - Show this help message
  cat          - Extract data from a file
  info         - Display filesystem information
  ls           - List directory contents
  exit/quit    - Exit the browser

> ls

Contents of '/':
Name                      Type       Mode     Size
------------------------------------------------------------
.                         dir        0x41ED 4.0 KB
..                        dir        0x41ED 4.0 KB
lost+found                dir        0x41C0 16.0 KB
home                      dir        0x41ED 4.0 KB
etc                       dir        0x41ED 4.0 KB
var                       dir        0x41ED 4.0 KB
usr                       dir        0x41ED 4.0 KB
tmp                       dir        0x41ED 4.0 KB
boot                      dir        0x41ED 4.0 KB
test_data                 dir        0x41ED 4.0 KB
hello.txt                 file       0x81A4 14 B

Total: 11 entries

> cat hello.txt

Content of 'hello.txt' (14 bytes):
Hello, World!

> exit
```

### Documentation

[/fslib](./src/fslib/description.md)
