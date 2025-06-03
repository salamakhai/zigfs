# ZIGFS

A filesystem toolset written in Zig  
[Github link](https://github.com/isalamaha/zigfs.git)


### TEST: Binary and test image included

```sh
./zig-out/bin/zigfs mount test/ext4fs.img 
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

## How to run globally

### Create a symbolic link (one of solutions)

Link the compiled `zigfs` binary to a directory that is already in `$PATH`, such as `/usr/local/bin`.  
Note: Run commands from the project folder  

**Run build to create binary**
```sh
zig build
```  
**Ensure the binary is executable**
```sh
chmod +x zig-out/bin/zigfs
```  
**Create symlink to the binary**
```sh
sudo ln -s "$(pwd)/zig-out/bin/zigfs" /usr/local/bin/zigfs
```  
**Verify**
```sh
zigfs
```  

---
  
_To remove symlink later:_
```sh
sudo rm /usr/local/bin/zigfs
```


## Create ext4 fs for tests
### MacOS

```sh
dd if=/dev/zero of=ext4.img bs=1M count=0 seek=64
```

Run Docker
```sh
docker run --rm -it -v $(pwd):/work -w /work ubuntu
```

```sh
>>> apt-get update && apt-get install -y e2fsprogs
```

```sh
>>> mkfs.ext4 ext4.img
```

```sh
>>> exit
```
  
  
  


## TODOs and notes
- [ ] file system module
- [ ] mount ls sub-command
- [ ] mount cut sub-command
- [ ] Create tests for commands
- [ ] Progress indicators for long operations  
  
---  

  
- [x] Recursive files finder
- [x] FUSE research
- [x] Reader/Writer for runner interactive mode?
- [x] Multi steps commands, chains
- [x] loop for interactive (session) mode?

?Ideas:
- [ ] Extender of file's metadata: create tag system for files searching
