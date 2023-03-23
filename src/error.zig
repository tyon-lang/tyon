const std = @import("std");

pub fn printExit(comptime fmt: []const u8, args: anytype, status: u8) noreturn {
    std.debug.print(fmt ++ "\n", args);
    std.process.exit(status);
}

pub fn errorAt(comptime fmt: []const u8, line: usize, column: usize, size: usize, args: anytype, status: u8) noreturn {
    printExit("[{d}, {d}-{d}] " ++ fmt, .{ line + 1, column + 1, column + size + 1 } ++ args, status);
}
