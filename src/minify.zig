const std = @import("std");
const Error = std.fs.File.WriteError;

const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;

pub fn minify(writer: anytype, node: *Node) Error!void {
    switch (node.getType()) {
        .discard => _ = try writer.write("_"),
        .file => try printItems(writer, node.asFile()),
        .list => {
            _ = try writer.write("[");
            try printItems(writer, node.asList());
            _ = try writer.write("]");
        },
        .map => {
            _ = try writer.write("(");
            try printItems(writer, node.asMap());
            _ = try writer.write(")");
        },
        .string => try writer.print("\"{s}\"", .{node.asString()}),
        .typed => {
            _ = try writer.write("/");
            try minify(writer, node.asTyped().type);
            try minify(writer, node.asTyped().node);
        },
        .typedef => {
            _ = try writer.write("(/");
            try printItems(writer, node.asTypedef());
            _ = try writer.write(")");
        },
        .value => _ = try writer.write(node.asValue()),
    }
}

fn printItems(writer: anytype, nodes: *NodeList) Error!void {
    var current = nodes.first;
    var first = true;
    while (current) |cur| : (current = cur.next) {
        if (first) {
            first = false;
        } else {
            _ = try writer.write(" ");
        }
        try minify(writer, cur);
    }
}
