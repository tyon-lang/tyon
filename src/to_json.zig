const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = std.fs.File.WriteError;

const StrList = std.ArrayList([]const u8);
const TypeMap = std.StringHashMap(*Node);

const err = @import("error.zig");
const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;

pub fn toJson(alloc: Allocator, writer: anytype, node: *Node) !void {
    var strings = StrList.init(alloc);
    defer strings.deinit();

    var types = TypeMap.init(alloc);
    defer types.deinit();

    try writeFile(writer, node.asFile(), &strings, &types);

    for (strings.items) |string| {
        alloc.free(string);
    }
}

fn getKey(node: *Node, strings: *StrList) []const u8 {
    _ = strings;

    switch (node.getType()) {
        .string => {
            // todo - unescape "
            return node.asString();
        },
        .value => return node.asValue(),
        else => unreachable,
    }
}

fn loadTypedef(typedef: *NodeList, strings: *StrList, types: *TypeMap) !void {
    if (typedef.first) |name| {
        if (name.next) |first_val| {
            const key = getKey(name, strings);
            try types.put(key, first_val);
        } else {
            err.printExit("Typedef must have at least one value", .{}, 65);
        }
    } else {
        err.printExit("Typedef must have a name", .{}, 65);
    }
}

fn writeFile(writer: anytype, file: *NodeList, strings: *StrList, types: *TypeMap) !void {
    _ = try writer.write("{\n");

    var first_pair = true;
    var current = file.first;
    while (current) |key| {
        if (key.getType() == .typedef) {
            try loadTypedef(key.asTypedef(), strings, types);
            current = key.next;
        } else if (key.next) |value| {
            if (first_pair) {
                first_pair = false;
            } else {
                _ = try writer.write(",\n");
            }
            try indent(writer, 1);
            try writeKey(writer, key);
            _ = try writer.write(": ");
            try writeValue(writer, value, 1);
            current = value.next;
        } else {
            err.printExit("File has a mismatched number of keys and values", .{}, 65);
        }
    }

    _ = try writer.write("\n}");
}

fn writeKey(writer: anytype, node: *Node) Error!void {
    switch (node.getType()) {
        .string => {
            _ = try writer.write("\"");
            // todo - escape various characters
            _ = try writer.write(node.asString());
            _ = try writer.write("\"");
        },
        .value => {
            // todo - parse and check for value patterns and then always write them as strings
            _ = try writer.write("\"");
            // todo - escape "
            _ = try writer.write(node.asValue());
            _ = try writer.write("\"");
        },
        else => unreachable,
    }
}

fn writeList(writer: anytype, list: *NodeList, indent_level: usize) Error!void {
    _ = try writer.write("[\n");

    var first = true;
    var current = list.first;
    while (current) |cur| : (current = cur.next) {
        if (first) {
            first = false;
        } else {
            _ = try writer.write(",\n");
        }
        try indent(writer, indent_level + 1);
        try writeValue(writer, cur, indent_level + 1);
    }

    _ = try writer.write("\n");
    try indent(writer, indent_level);
    _ = try writer.write("]");
}

fn writeMap(writer: anytype, map: *NodeList, indent_level: usize) Error!void {
    _ = try writer.write("{\n");

    var first = true;
    var current = map.first;
    while (current) |key| {
        if (key.next) |value| {
            if (first) {
                first = false;
            } else {
                _ = try writer.write(",\n");
            }
            try indent(writer, indent_level + 1);
            try writeKey(writer, key);
            _ = try writer.write(": ");
            try writeValue(writer, value, indent_level + 1);
            current = value.next;
        } else {
            err.printExit("Map has a mismatched number of keys and values", .{}, 65);
        }
    }

    _ = try writer.write("\n");
    try indent(writer, indent_level);
    _ = try writer.write("}");
}

fn writeValue(writer: anytype, node: *Node, indent_level: usize) Error!void {
    switch (node.getType()) {
        .list => try writeList(writer, node.asList(), indent_level),
        .map => try writeMap(writer, node.asMap(), indent_level),
        .string => {
            _ = try writer.write("\"");
            // todo - escape various characters
            _ = try writer.write(node.asString());
            _ = try writer.write("\"");
        },
        .typed => {
            // todo
            _ = try writer.write("\"[typed]\"");
        },
        .value => {
            if (std.mem.eql(u8, node.asValue(), "true") or
                std.mem.eql(u8, node.asValue(), "false") or
                std.mem.eql(u8, node.asValue(), "null"))
            {
                _ = try writer.write(node.asValue());
            } else {
                // todo - numbers
                _ = try writer.write("\"");
                // todo - escape "
                _ = try writer.write(node.asValue());
                _ = try writer.write("\"");
            }
        },
        else => unreachable,
    }
}

fn indent(writer: anytype, indent_level: usize) !void {
    for (0..indent_level) |_| {
        _ = try writer.write("\t");
    }
}
