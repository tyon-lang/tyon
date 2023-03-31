const std = @import("std");
const Error = std.fs.File.WriteError;

const Node = @import("tree.zig").Node;

pub fn format(writer: anytype, node: Node, indent_level: usize) Error!void {
    switch (node.getType()) {
        .comment => try writer.print(";{s}", .{node.asComment()}),
        .file => try formatFile(writer, node, indent_level),
        .list => try formatList(writer, node, indent_level),
        .map => try formatMap(writer, node, indent_level),
        .string => try writer.print("\"{s}\"", .{node.asString()}),
        .value => try writer.writeAll(node.asValue()),
    }
}

fn formatFile(writer: anytype, file: Node, indent_level: usize) Error!void {
    const items = file.asFile().items;
    if (items.len > 0) {
        try writePairs(writer, items, file.start_line, false, indent_level);
        try writer.writeAll("\n");
    }
}

fn formatList(writer: anytype, list: Node, indent_level: usize) Error!void {
    try writer.writeAll("[");
    try writeItems(writer, list.asList().items, list.start_line, indent_level);
    try writer.writeAll("]");
}

fn formatMap(writer: anytype, map: Node, indent_level: usize) Error!void {
    try writer.writeAll("(");
    try writePairs(writer, map.asMap().items, map.start_line, true, indent_level);
    try writer.writeAll(")");
}

fn indent(writer: anytype, indent_level: usize) !void {
    for (0..indent_level) |_| {
        try writer.writeAll("\t");
    }
}

fn writeItems(writer: anytype, items: []const Node, start_line: usize, indent_level: usize) !void {
    var prior_line = start_line;
    var cur_indent = indent_level;

    if (items.len > 0) {
        if (items[0].start_line > prior_line) {
            cur_indent = indent_level + 1;
            try writer.writeAll("\n");
            try indent(writer, cur_indent);
        }
        try format(writer, items[0], cur_indent);
        prior_line = items[0].end_line;

        for (items[1..]) |node| {
            if (node.start_line > prior_line) {
                cur_indent = indent_level + 1;
                if (node.start_line == prior_line + 1) {
                    try writer.writeAll("\n");
                } else {
                    try writer.writeAll("\n\n");
                }
                try indent(writer, cur_indent);
            } else {
                try writer.writeAll(" ");
            }
            try format(writer, node, cur_indent);
            prior_line = node.end_line;
        }
    }

    if (cur_indent > indent_level) {
        try writer.writeAll("\n");
        try indent(writer, indent_level);
    }
}

fn writePairs(writer: anytype, items: []const Node, start_line: usize, do_indent: bool, indent_level: usize) !void {
    var prior_line = start_line;
    var cur_indent = indent_level;

    if (items.len > 0) {
        if (items[0].start_line > prior_line) {
            if (do_indent) cur_indent = indent_level + 1;
            try writer.writeAll("\n");
            try indent(writer, cur_indent);
        }
        try format(writer, items[0], cur_indent);
        prior_line = items[0].end_line;
        var prior_comment = items[0].isComment();
        var second = !prior_comment;

        for (items[1..]) |node| {
            if (prior_comment or !(second or (node.start_line == prior_line and node.isComment()))) {
                if (do_indent) cur_indent = indent_level + 1;
                if (!second and node.start_line > prior_line + 1) {
                    try writer.writeAll("\n\n");
                } else {
                    try writer.writeAll("\n");
                }
                try indent(writer, cur_indent);
            } else {
                try writer.writeAll(" ");
            }

            try format(writer, node, cur_indent);
            prior_line = node.end_line;

            prior_comment = node.isComment();
            if (!prior_comment) {
                second = !second;
            }
        }
    }

    if (cur_indent > indent_level) {
        try writer.writeAll("\n");
        try indent(writer, indent_level);
    }
}
