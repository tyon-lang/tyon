const std = @import("std");
const Allocator = std.mem.Allocator;

const err = @import("error.zig");
const format = @import("format.zig");
const Parser = @import("parser.zig").Parser;
const to_json = @import("to_json.zig");

const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0, .pre = "dev.8" };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    var arg_list = std.ArrayList([]const u8).init(alloc);
    defer arg_list.deinit();

    while (args.next()) |arg| try arg_list.append(arg);

    var valid = false;
    if (arg_list.items.len >= 3 and std.mem.eql(u8, arg_list.items[1], "debug")) {
        valid = true;
        for (arg_list.items[2..]) |file| {
            try fileDebug(alloc, file);
        }
    } else if (arg_list.items.len >= 3 and std.mem.eql(u8, arg_list.items[1], "format")) {
        valid = true;
        for (arg_list.items[2..]) |file| {
            try fileFormat(alloc, file);
        }
    } else if (arg_list.items.len >= 2 and std.mem.eql(u8, arg_list.items[1], "help")) {
        valid = true;
        printUsage();
    } else if (arg_list.items.len >= 3 and std.mem.eql(u8, arg_list.items[1], "to-json")) {
        valid = true;
        for (arg_list.items[2..]) |file| {
            try fileToJson(alloc, file);
        }
    } else if (arg_list.items.len >= 3 and std.mem.eql(u8, arg_list.items[1], "validate")) {
        valid = true;
        for (arg_list.items[2..]) |file| {
            try fileValidate(alloc, file);
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

fn fileDebug(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    var parser = Parser.init(alloc, source, true);
    defer parser.deinit();

    const result = parser.parse();
    result.print();
}

fn fileFormat(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    file.close();
    // todo
    // file = try std.fs.cwd().createFile(path, .{});
    // defer file.close();

    // var buffered_writer = std.io.bufferedWriter(file.writer());

    var parser = Parser.init(alloc, source, true);
    defer parser.deinit();

    const result = parser.parse();
    result.print(); // todo - remove

    // todo
    // try format.format(buffered_writer.writer(), root, 0);
    // try buffered_writer.flush();
}

fn fileToJson(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    const strings = [_][]const u8{ path, ".json" };
    const out_path = std.mem.concat(alloc, u8, &strings) catch {
        err.printExit("Could not allocate memory for path.", .{}, 1);
    };
    defer alloc.free(out_path);

    var out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();

    var buffered_writer = std.io.bufferedWriter(out_file.writer());

    var parser = Parser.init(alloc, source, false);
    defer parser.deinit();

    const result = parser.parse();
    try to_json.toJson(alloc, buffered_writer.writer(), result.root);
    try buffered_writer.flush();
}

fn fileValidate(alloc: Allocator, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    var parser = Parser.init(alloc, source, false);
    defer parser.deinit();

    const result = parser.parse();
    // todo - validate
    _ = result;
}

fn printUsage() void {
    std.debug.print(
        \\Usage: tyon <command>
        \\
        \\Commands:
        \\  format <files>      Format specified files
        \\  to-json <files>     Save files as JSON
        \\  validate <files>    Validate specified files
        \\
        \\  debug <files>       Debug the specified files
        \\
        \\  help                Print this help and exit
        \\  version             Print version and exit
        \\
    , .{});
}
