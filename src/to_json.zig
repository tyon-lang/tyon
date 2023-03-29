const std = @import("std");
const Error = std.fs.File.WriteError;

const err = @import("error.zig");
const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;

pub fn toJson(writer: anytype, node: *Node) Error!void {
    try writeFile(writer, node.asFile());
}

fn writeFile(writer: anytype, file: *NodeList) Error!void {
    _ = try writer.write("{\n");

    var first_pair = true;
    var current = file.first;
    while (current) |key| {
        if (key.getType() == .typedef) {
            // todo - typedef
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
            // todo - parse and check for value patterns
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
            // todo - parse and check for value patterns
            _ = try writer.write("\"");
            // todo - escape "
            _ = try writer.write(node.asValue());
            _ = try writer.write("\"");
        },
        else => unreachable,
    }
}

fn indent(writer: anytype, indent_level: usize) !void {
    for (0..indent_level) |_| {
        _ = try writer.write("\t");
    }
}
