const std = @import("std");
const Allocator = std.mem.Allocator;

const format = @import("format.zig");
const Parser = @import("parser.zig").Parser;

const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0, .pre = "dev.3" };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    var arg_list = std.ArrayList([]const u8).init(alloc);
    defer arg_list.deinit();

    while (args.next()) |arg| try arg_list.append(arg);

    var valid = false;
    if (arg_list.items.len >= 3 and std.mem.eql(u8, arg_list.items[1], "format")) {
        valid = true;
        for (arg_list.items[2..]) |file| {
            try formatFile(alloc, file);
        }
    } else if (arg_list.items.len >= 2 and std.mem.eql(u8, arg_list.items[1], "help")) {
        valid = true;
        printUsage();
    } else if (arg_list.items.len >= 3 and std.mem.eql(u8, arg_list.items[1], "minify")) {
        valid = true;
        for (arg_list.items[2..]) |file| {
            try minifyFile(alloc, file);
        }
    } else if (arg_list.items.len >= 4 and std.mem.eql(u8, arg_list.items[1], "to") and std.mem.eql(u8, arg_list.items[2], "json")) {
        valid = true;
        for (arg_list.items[3..]) |file| {
            try toJson(alloc, file);
        }
    } else if (arg_list.items.len >= 3 and std.mem.eql(u8, arg_list.items[1], "validate")) {
        valid = true;
        for (arg_list.items[2..]) |file| {
            try validateFile(alloc, file);
        }
    } else if (arg_list.items.len >= 2 and std.mem.eql(u8, arg_list.items[1], "version")) {
        valid = true;
        try version.format("", .{}, std.io.getStdErr().writer());
        std.debug.print("\n", .{});
    }

    if (!valid) {
        printUsage();
        std.process.exit(64);
    }
}

fn formatFile(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    file.close();
    // todo
    // file = try std.fs.cwd().createFile(path, .{});
    // defer file.close();

    // var buffered_writer = std.io.bufferedWriter(file.writer());

    var parser: Parser = undefined;
    parser.init(alloc, source, true);
    defer parser.deinit();

    const result = parser.parse();
    result.print(); // todo - remove

    // todo
    // try format.format(buffered_writer.writer(), root, 0);
    // try buffered_writer.flush();
}

fn minifyFile(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    file.close();
    file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var buffered_writer = std.io.bufferedWriter(file.writer());

    // todo - minify

    try buffered_writer.flush();
}

fn toJson(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    // todo - save as json
}

fn validateFile(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    // todo - validate
}

fn printUsage() void {
    std.debug.print(
        \\Usage: tyon <command>
        \\
        \\Commands:
        \\  format <files>      Format specified files
        \\  minify <files>      Minify specified files
        \\  validate <files>    Validate specified files
        \\
        \\  to json <files>     Save files as JSON
        \\
        \\  help                Print this help and exit
        \\  version             Print version and exit
        \\
    , .{});
}
