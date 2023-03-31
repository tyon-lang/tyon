const std = @import("std");

pub fn printExit(comptime fmt: []const u8, args: anytype, status: u8) noreturn {
    std.debug.print(fmt ++ "\n", args);
    std.process.exit(status);
}
