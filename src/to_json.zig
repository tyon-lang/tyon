const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = std.fs.File.WriteError;

const StrList = std.ArrayList([]const u8);
const TypeMap = std.StringHashMap(*Node);

const err = @import("error.zig");
const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;
const TypedNode = @import("tree.zig").TypedNode;

pub const ToJson = struct {
    allocator: Allocator,
    strings: StrList,
    types: TypeMap,

    pub fn convert(alloc: Allocator, writer: anytype, node: *Node) !void {
        var converter = init(alloc);
        defer converter.deinit();
        try converter.writeFile(writer, node.asFile());
    }

    fn init(alloc: Allocator) ToJson {
        return .{
            .allocator = alloc,
            .strings = StrList.init(alloc),
            .types = TypeMap.init(alloc),
        };
    }

    fn deinit(self: *ToJson) void {
        for (self.strings.items) |string| {
            self.allocator.free(string);
        }
        self.strings.deinit();
        self.types.deinit();
    }

    fn getKey(self: *ToJson, node: *Node) []const u8 {
        _ = self;

        switch (node.getType()) {
            .string => {
                // todo - unescape "
                return node.asString();
            },
            .value => return node.asValue(),
            else => unreachable,
        }
    }

    fn loadTypedef(self: *ToJson, typedef: *NodeList) !void {
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

    fn writeFile(self: *ToJson, writer: anytype, file: *NodeList) !void {
        _ = try writer.write("{\n");

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
                    _ = try writer.write(",\n");
                }
                try indent(writer, 1);
                try writeKey(writer, key);
                _ = try writer.write(": ");
                try self.writeValue(writer, value, null, 1);
                current = value.next;
            } else {
                err.printExit("File has a mismatched number of keys and values", .{}, 65);
            }
        }

        _ = try writer.write("\n}");
    }

    fn writeKey(writer: anytype, node: *Node) !void {
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

    fn writeList(self: *ToJson, writer: anytype, list: *NodeList, type_keys: ?*Node, indent_level: usize) !void {
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
            try self.writeValue(writer, cur, type_keys, indent_level + 1);
        }

        _ = try writer.write("\n");
        try indent(writer, indent_level);
        _ = try writer.write("]");
    }

    fn writeMap(self: *ToJson, writer: anytype, map: *NodeList, type_keys: ?*Node, indent_level: usize) !void {
        _ = try writer.write("{\n");

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
                            _ = try writer.write(",\n");
                        }
                        try indent(writer, indent_level + 1);
                        try writeKey(writer, key);
                        _ = try writer.write(": ");
                        try self.writeValue(writer, value, null, indent_level + 1);
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
                        _ = try writer.write(",\n");
                    }
                    try indent(writer, indent_level + 1);
                    try writeKey(writer, key);
                    _ = try writer.write(": ");
                    try self.writeValue(writer, value, null, indent_level + 1);
                    current = value.next;
                } else {
                    err.printExit("Map has a mismatched number of keys and values", .{}, 65);
                }
            }
        }

        _ = try writer.write("\n");
        try indent(writer, indent_level);
        _ = try writer.write("}");
    }

    fn writeTyped(self: *ToJson, writer: anytype, node: *TypedNode, indent_level: usize) Error!void {
        const keys = switch (node.type.getType()) {
            .discard => null,
            .map => node.type.asMap().first,
            .string => b: {
                // todo - unescape "
                break :b self.types.get(node.type.asString());
            },
            .value => self.types.get(node.type.asValue()),
            else => unreachable,
        };
        switch (node.node.getType()) {
            .list => try self.writeList(writer, node.node.asList(), keys, indent_level),
            .map => try self.writeMap(writer, node.node.asMap(), keys, indent_level),
            else => unreachable,
        }
    }

    fn writeValue(self: *ToJson, writer: anytype, node: *Node, type_keys: ?*Node, indent_level: usize) Error!void {
        switch (node.getType()) {
            .list => try self.writeList(writer, node.asList(), type_keys, indent_level),
            .map => try self.writeMap(writer, node.asMap(), type_keys, indent_level),
            .string => {
                _ = try writer.write("\"");
                // todo - escape various characters
                _ = try writer.write(node.asString());
                _ = try writer.write("\"");
            },
            .typed => try self.writeTyped(writer, node.asTyped(), indent_level),
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
};
