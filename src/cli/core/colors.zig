const std = @import("std");

pub const Colors = struct {
    var colors_enabled: ?bool = null;
    
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    
    // Regular colors
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const white = "\x1b[37m";
    
    // Bright colors
    pub const bright_red = "\x1b[91m";
    pub const bright_green = "\x1b[92m";
    pub const bright_yellow = "\x1b[93m";
    pub const bright_blue = "\x1b[94m";
    pub const bright_magenta = "\x1b[95m";
    pub const bright_cyan = "\x1b[96m";
    
    pub fn isSupported() bool {
        if (colors_enabled) |cached_status| {
            return cached_status;
        }

        const allocator = std.heap.page_allocator;
        const term = std.process.getEnvVarOwned(allocator, "TERM") catch {
            colors_enabled = false;
            return false;
        };
        defer allocator.free(term);

        const supports_color = std.mem.indexOf(u8, term, "color") != null or
                              std.mem.indexOf(u8, term, "xterm") != null or
                              std.mem.indexOf(u8, term, "256") != null;
        
        colors_enabled = supports_color;
        return supports_color;
    }
    
    pub fn get(color: []const u8) []const u8 {
        return if (isSupported()) color else "";
    }
};