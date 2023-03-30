const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = std.fs.File.WriteError;

const StrList = std.ArrayList([]const u8);
const TypeMap = std.StringHashMap(*Node);

const err = @import("error.zig");
const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;
const TypedNode = @import("tree.zig").TypedNode;

pub fn convert(allocator: Allocator, output_writer: anytype, root_node: *Node) !void {
    const converter = struct {
        const Self = @This();

        allocator: Allocator,
        writer: @TypeOf(output_writer),
        strings: StrList,
        types: TypeMap,

        fn init(alloc: Allocator, writer: @TypeOf(output_writer)) Self {
            return .{
                .allocator = alloc,
                .writer = writer,
                .strings = StrList.init(alloc),
                .types = TypeMap.init(alloc),
            };
        }

        fn deinit(self: *Self) void {
            for (self.strings.items) |string| {
                self.allocator.free(string);
            }
            self.strings.deinit();
            self.types.deinit();
        }

        fn getKey(self: *Self, node: *Node) []const u8 {
            switch (node.getType()) {
                .string => {
                    const str = node.asString();
                    var count: usize = 0;
                    for (str) |c| {
                        if (c == '"') count += 1;
                    }
                    if (count == 0) {
                        return str;
                    } else {
                        const new_len = str.len - (count / 2);
                        const heap_chars = self.allocator.alloc(u8, new_len) catch {
                            err.printExit("Could not allocate memory for string.", .{}, 1);
                        };
                        self.strings.append(heap_chars) catch {
                            err.printExit("Could not allocate memory for string.", .{}, 1);
                        };
                        var i: usize = 0;
                        var index: usize = 0;
                        while (i < str.len) : (i += 1) {
                            if (str[i] == '"') i += 1;
                            heap_chars[index] = str[i];
                            index += 1;
                        }
                        return heap_chars;
                    }
                },
                .value => return node.asValue(),
                else => unreachable,
            }
        }

        fn loadTypedef(self: *Self, typedef: *NodeList) !void {
            if (typedef.first) |name| {
                if (name.next) |first_val| {
                    const key = self.getKey(name);
                    try self.types.put(key, first_val);
                } else {
                    err.printExit("Typedef must have at least one value", .{}, 65);
                }
            } else {
                err.printExit("Typedef must have a name", .{}, 65);
            }
        }

        fn writeFile(self: *Self, file: *NodeList) !void {
            _ = try self.writer.write("{\n");

            var first_pair = true;
            var current = file.first;
            while (current) |key| {
                if (key.getType() == .typedef) {
                    try self.loadTypedef(key.asTypedef());
                    current = key.next;
                } else if (key.next) |value| {
                    if (first_pair) {
                        first_pair = false;
                    } else {
                        _ = try self.writer.write(",\n");
                    }
                    try self.indent(1);
                    try self.writeKey(key);
                    _ = try self.writer.write(": ");
                    try self.writeValue(value, null, 1);
                    current = value.next;
                } else {
                    err.printExit("File has a mismatched number of keys and values", .{}, 65);
                }
            }

            _ = try self.writer.write("\n}");
        }

        fn writeKey(self: *Self, node: *Node) !void {
            switch (node.getType()) {
                .string => {
                    _ = try self.writer.write("\"");
                    try self.writeStringEscaped(node.asString());
                    _ = try self.writer.write("\"");
                },
                .value => {
                    // todo - parse and check for numbers and then write them as strings
                    _ = try self.writer.write("\"");
                    try self.writeValueEscaped(node.asValue());
                    _ = try self.writer.write("\"");
                },
                else => unreachable,
            }
        }

        fn writeList(self: *Self, list: *NodeList, type_keys: ?*Node, indent_level: usize) !void {
            _ = try self.writer.write("[\n");

            var first = true;
            var current = list.first;
            while (current) |cur| : (current = cur.next) {
                if (first) {
                    first = false;
                } else {
                    _ = try self.writer.write(",\n");
                }
                try self.indent(indent_level + 1);
                try self.writeValue(cur, type_keys, indent_level + 1);
            }

            _ = try self.writer.write("\n");
            try self.indent(indent_level);
            _ = try self.writer.write("]");
        }

        fn writeMap(self: *Self, map: *NodeList, type_keys: ?*Node, indent_level: usize) !void {
            _ = try self.writer.write("{\n");

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
                                _ = try self.writer.write(",\n");
                            }
                            try self.indent(indent_level + 1);
                            try self.writeKey(key);
                            _ = try self.writer.write(": ");
                            try self.writeValue(value, null, indent_level + 1);
                        }
                        curr_key = key.next;
                    } else {
                        err.printExit("Typed map has more values than keys", .{}, 65);
                    }
                }
            } else {
                while (current) |key| {
                    if (key.next) |value| {
                        if (first) {
                            first = false;
                        } else {
                            _ = try self.writer.write(",\n");
                        }
                        try self.indent(indent_level + 1);
                        try self.writeKey(key);
                        _ = try self.writer.write(": ");
                        try self.writeValue(value, null, indent_level + 1);
                        current = value.next;
                    } else {
                        err.printExit("Map has a mismatched number of keys and values", .{}, 65);
                    }
                }
            }

            _ = try self.writer.write("\n");
            try self.indent(indent_level);
            _ = try self.writer.write("}");
        }

        fn writeTyped(self: *Self, node: *TypedNode, indent_level: usize) Error!void {
            const keys = switch (node.type.getType()) {
                .discard => null,
                .map => node.type.asMap().first,
                .string => b: {
                    const key = self.getKey(node.type);
                    break :b self.types.get(key);
                },
                .value => self.types.get(node.type.asValue()),
                else => unreachable,
            };
            switch (node.node.getType()) {
                .list => try self.writeList(node.node.asList(), keys, indent_level),
                .map => try self.writeMap(node.node.asMap(), keys, indent_level),
                else => unreachable,
            }
        }

        fn writeValue(self: *Self, node: *Node, type_keys: ?*Node, indent_level: usize) Error!void {
            switch (node.getType()) {
                .list => try self.writeList(node.asList(), type_keys, indent_level),
                .map => try self.writeMap(node.asMap(), type_keys, indent_level),
                .string => {
                    _ = try self.writer.write("\"");
                    try self.writeStringEscaped(node.asString());
                    _ = try self.writer.write("\"");
                },
                .typed => try self.writeTyped(node.asTyped(), indent_level),
                .value => {
                    if (std.mem.eql(u8, node.asValue(), "true") or
                        std.mem.eql(u8, node.asValue(), "false") or
                        std.mem.eql(u8, node.asValue(), "null"))
                    {
                        _ = try self.writer.write(node.asValue());
                    } else {
                        // todo - numbers
                        _ = try self.writer.write("\"");
                        try self.writeValueEscaped(node.asValue());
                        _ = try self.writer.write("\"");
                    }
                },
                else => unreachable,
            }
        }

        fn writeStringEscaped(self: *Self, str: []const u8) !void {
            var i: usize = 0;
            while (i < str.len) : (i += 1) {
                switch (str[i]) {
                    '"' => {
                        i += 1;
                        _ = try self.writer.write("\\\"");
                    },
                    '\\' => _ = try self.writer.write("\\\\"),
                    '/' => _ = try self.writer.write("\\/"),
                    8 => _ = try self.writer.write("\\b"),
                    12 => _ = try self.writer.write("\\f"),
                    '\n' => _ = try self.writer.write("\\n"),
                    '\r' => _ = try self.writer.write("\\r"),
                    '\t' => _ = try self.writer.write("\\t"),
                    else => try self.writer.writeByte(str[i]),
                }
            }
        }

        fn writeValueEscaped(self: *Self, val: []const u8) !void {
            for (val) |c| {
                if (c == '"') _ = try self.writer.write("\\");
                try self.writer.writeByte(c);
            }
        }

        fn indent(self: *Self, indent_level: usize) !void {
            for (0..indent_level) |_| {
                _ = try self.writer.write("\t");
            }
        }
    };

    var conv = converter.init(allocator, output_writer);
    defer conv.deinit();
    try conv.writeFile(root_node.asFile());
}
