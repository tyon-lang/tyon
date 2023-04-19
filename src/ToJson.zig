const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = error{Semantics} || std.fs.File.WriteError;

const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;
const TypedNode = @import("tree.zig").TypedNode;

pub fn convert(allocator: Allocator, output_writer: anytype, root_node: *Node) !void {
    const converter = struct {
        const Self = @This();

        allocator: Allocator,
        writer: @TypeOf(output_writer),
        types: std.StringHashMap(*Node),

        fn init(alloc: Allocator, writer: @TypeOf(output_writer)) Self {
            return .{
                .allocator = alloc,
                .writer = writer,
                .types = std.StringHashMap(*Node).init(alloc),
            };
        }

        fn deinit(self: *Self) void {
            self.types.deinit();
        }

        fn semanticError(comptime fmt: []const u8, args: anytype) !void {
            std.debug.print(fmt ++ "\n", args);
            return error.Semantics;
        }

        fn loadType(self: *Self, name: []const u8, keys: ?*Node) !void {
            if (keys) |first| {
                try self.types.put(name, first);
            } else {
                try semanticError("Typedef must have at least one key", .{});
            }
        }

        fn writeFile(self: *Self, file: *NodeList) !void {
            try self.writer.writeAll("{\n");

            var first_pair = true;
            var current = file.first;
            while (current) |key| {
                if (key.next) |value| {
                    if (key.getType() == .type_name) {
                        try self.loadType(key.asTypeName(), value.asMap().first);
                    } else {
                        if (first_pair) {
                            first_pair = false;
                        } else {
                            try self.writer.writeAll(",\n");
                        }
                        try self.indent(1);
                        try self.writeKey(key);
                        try self.writer.writeAll(": ");
                        try self.writeValue(value, null, 1);
                    }
                    current = value.next;
                } else {
                    try semanticError("File has a mismatched number of keys and values", .{});
                }
            }

            try self.writer.writeAll("\n}");
        }

        fn writeKey(self: *Self, node: *Node) !void {
            switch (node.getType()) {
                .literal => {
                    if (node.number()) |num| {
                        try self.writer.print("\"{d}\"", .{num});
                    } else {
                        try self.writer.writeAll("\"");
                        try self.writeLiteralEscaped(node.asLiteral());
                        try self.writer.writeAll("\"");
                    }
                },
                .string => {
                    try self.writer.writeAll("\"");
                    try self.writeStringEscaped(node.asString());
                    try self.writer.writeAll("\"");
                },
                else => unreachable,
            }
        }

        fn writeList(self: *Self, list: *NodeList, type_keys: ?*Node, indent_level: usize) Error!void {
            try self.writer.writeAll("[\n");

            var first = true;
            var current = list.first;
            while (current) |cur| : (current = cur.next) {
                if (first) {
                    first = false;
                } else {
                    try self.writer.writeAll(",\n");
                }
                try self.indent(indent_level + 1);
                try self.writeValue(cur, type_keys, indent_level + 1);
            }

            try self.writer.writeAll("\n");
            try self.indent(indent_level);
            try self.writer.writeAll("]");
        }

        fn writeMap(self: *Self, map: *NodeList, type_keys: ?*Node, indent_level: usize) Error!void {
            try self.writer.writeAll("{\n");

            var first = true;
            var current = map.first;
            if (type_keys) |_| {
                var curr_key = type_keys;
                while (current) |value| : (current = value.next) {
                    if (curr_key) |key| {
                        if (value.getType() != .discard) {
                            if (first) {
                                first = false;
                            } else {
                                try self.writer.writeAll(",\n");
                            }
                            try self.indent(indent_level + 1);
                            try self.writeKey(key);
                            try self.writer.writeAll(": ");
                            try self.writeValue(value, null, indent_level + 1);
                        }
                        curr_key = key.next;
                    } else {
                        try semanticError("Typed map has more values than keys", .{});
                    }
                }
            } else {
                while (current) |key| {
                    if (key.next) |value| {
                        if (first) {
                            first = false;
                        } else {
                            try self.writer.writeAll(",\n");
                        }
                        try self.indent(indent_level + 1);
                        try self.writeKey(key);
                        try self.writer.writeAll(": ");
                        try self.writeValue(value, null, indent_level + 1);
                        current = value.next;
                    } else {
                        try semanticError("Map has a mismatched number of keys and values", .{});
                    }
                }
            }

            try self.writer.writeAll("\n");
            try self.indent(indent_level);
            try self.writer.writeAll("}");
        }

        fn writeTyped(self: *Self, node: *TypedNode, indent_level: usize) !void {
            const keys = switch (node.type.getType()) {
                .discard => null,
                .map => node.type.asMap().first,
                .type_name => self.types.get(node.type.asTypeName()),
                else => unreachable,
            };
            switch (node.node.getType()) {
                .list => try self.writeList(node.node.asList(), keys, indent_level),
                .map => try self.writeMap(node.node.asMap(), keys, indent_level),
                else => unreachable,
            }
        }

        fn writeValue(self: *Self, node: *Node, type_keys: ?*Node, indent_level: usize) !void {
            switch (node.getType()) {
                .list => try self.writeList(node.asList(), type_keys, indent_level),
                .literal => {
                    if (std.mem.eql(u8, node.asLiteral(), "true") or
                        std.mem.eql(u8, node.asLiteral(), "false") or
                        std.mem.eql(u8, node.asLiteral(), "null"))
                    {
                        try self.writer.writeAll(node.asLiteral());
                    } else if (node.number()) |num| {
                        try self.writer.print("{d}", .{num});
                    } else {
                        try self.writer.writeAll("\"");
                        try self.writeLiteralEscaped(node.asLiteral());
                        try self.writer.writeAll("\"");
                    }
                },
                .map => try self.writeMap(node.asMap(), type_keys, indent_level),
                .string => {
                    try self.writer.writeAll("\"");
                    try self.writeStringEscaped(node.asString());
                    try self.writer.writeAll("\"");
                },
                .typed => try self.writeTyped(node.asTyped(), indent_level),
                else => unreachable,
            }
        }

        fn writeLiteralEscaped(self: *Self, val: []const u8) !void {
            for (val) |c| {
                switch (c) {
                    '"' => try self.writer.writeAll("\\\""),
                    '\\' => try self.writer.writeAll("\\\\"),
                    8 => try self.writer.writeAll("\\b"),
                    12 => try self.writer.writeAll("\\f"),
                    '\n' => try self.writer.writeAll("\\n"),
                    '\r' => try self.writer.writeAll("\\r"),
                    '\t' => try self.writer.writeAll("\\t"),
                    else => try self.writer.writeByte(c),
                }
            }
        }

        fn writeStringEscaped(self: *Self, str: []const u8) !void {
            var i: usize = 0;
            while (i < str.len) : (i += 1) {
                switch (str[i]) {
                    '"' => {
                        i += 1;
                        try self.writer.writeAll("\\\"");
                    },
                    '\\' => try self.writer.writeAll("\\\\"),
                    8 => try self.writer.writeAll("\\b"),
                    12 => try self.writer.writeAll("\\f"),
                    '\n' => try self.writer.writeAll("\\n"),
                    '\r' => try self.writer.writeAll("\\r"),
                    '\t' => try self.writer.writeAll("\\t"),
                    else => try self.writer.writeByte(str[i]),
                }
            }
        }

        fn indent(self: *Self, indent_level: usize) !void {
            for (0..indent_level) |_| {
                try self.writer.writeAll("\t");
            }
        }
    };

    var conv = converter.init(allocator, output_writer);
    defer conv.deinit();
    try conv.writeFile(root_node.asFile());
}
