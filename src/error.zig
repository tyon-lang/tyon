const std = @import("std");

pub fn printExit(comptime fmt: []const u8, args: anytype, status: u8) noreturn {
    std.debug.print(fmt ++ "\n", args);
    std.process.exit(status);
}

pub fn errorAt(comptime fmt: []const u8, s_line: usize, s_column: usize, e_line: usize, e_column: usize, args: anytype, status: u8) noreturn {
    printExit("[{d}, {d}]-[{d}, {d}] " ++ fmt, .{ s_line + 1, s_column + 1, e_line + 1, e_column + 1 } ++ args, status);
}
