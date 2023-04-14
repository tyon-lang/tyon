const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;

const TypeInfo = struct {
    node: *Node,
    count: usize,
    used: bool,

    fn init(name_node: *Node) TypeInfo {
        return .{
            .node = name_node,
            .count = 0,
            .used = false,
        };
    }
};

pub const Validator = struct {
    allocator: Allocator,
    has_error: bool,
    strings: std.ArrayList([]const u8),
    types: std.StringHashMap(TypeInfo),

    fn init(alloc: Allocator) Validator {
        return .{
            .allocator = alloc,
            .has_error = false,
            .strings = std.ArrayList([]const u8).init(alloc),
            .types = std.StringHashMap(TypeInfo).init(alloc),
        };
    }

    fn deinit(self: *Validator) void {
        for (self.strings.items) |string| {
            self.allocator.free(string);
        }
        self.strings.deinit();
        self.types.deinit();
    }

    fn hasError(self: *Validator, node: *Node, comptime fmt: []const u8, args: anytype) void {
        if (node.start_line == node.end_line) {
            std.debug.print("  [{d}, {d}-{d}] " ++ fmt ++ "\n", .{
                node.start_line + 1,
                node.start_column + 1,
                node.end_column + 1,
            } ++ args);
        } else {
            std.debug.print("  [{d}, {d}]-[{d}, {d}] " ++ fmt ++ "\n", .{
                node.start_line + 1,
                node.start_column + 1,
                node.end_line + 1,
                node.end_column + 1,
            } ++ args);
        }
        self.has_error = true;
    }

    pub fn validate(alloc: Allocator, root: *Node) !void {
        var validator = init(alloc);
        defer validator.deinit();

        try validator.validateNode(root, null);

        if (validator.has_error) {
            return error.Semantics;
        } else {
            std.debug.print("  Success\n", .{});
        }
    }

    fn validateKey(self: *Validator, keys: *std.StringHashMap(void), key: *Node) !void {
        switch (key.getType()) {
            .literal => {
                // keys are unique
                if (keys.contains(key.asLiteral())) {
                    self.hasError(key, "Duplicate key '{s}'", .{key.asLiteral()});
                } else {
                    try keys.put(key.asLiteral(), {});
                }
            },
            .string => {
                // unescape quotes
                const str = key.asString();
                const size = std.mem.replacementSize(u8, str, "\"\"", "\"");
                const unescaped = if (size == str.len) str else b: {
                    const heap_chars = try self.allocator.alloc(u8, size);
                    _ = std.mem.replace(u8, str, "\"\"", "\"", heap_chars);
                    try self.strings.append(heap_chars);
                    break :b heap_chars;
                };

                // keys are unique
                if (keys.contains(unescaped)) {
                    self.hasError(key, "Duplicate key '{s}'", .{unescaped});
                } else {
                    try keys.put(unescaped, {});
                }
            },
            else => unreachable,
        }
    }

    fn validateNode(self: *Validator, node: *Node, type_key_count: ?usize) !void {
        switch (node.getType()) {
            .file => {
                var keys = std.StringHashMap(void).init(self.allocator);
                defer keys.deinit();

                var current = node.asFile().first;
                while (current) |key| {
                    if (key.next) |value| {
                        switch (key.getType()) {
                            .literal, .string => {
                                // keys are unique
                                try self.validateKey(&keys, key);

                                // validate values
                                try self.validateNode(value, type_key_count);
                            },
                            .type_name => {
                                // type names are unique
                                if (self.types.contains(key.asTypeName())) {
                                    self.hasError(key, "Duplicate type '{s}'", .{key.asTypeName()});
                                } else {
                                    var info = TypeInfo.init(key);

                                    var type_keys = std.StringHashMap(void).init(self.allocator);
                                    defer type_keys.deinit();

                                    var type_cur = value.asMap().first;
                                    while (type_cur) |type_key| : (type_cur = type_key.next) {
                                        info.count += 1;
                                        // keys are unique
                                        try self.validateKey(&type_keys, type_key);
                                    }

                                    // type contains at least one key
                                    if (info.count < 1) {
                                        self.hasError(key, "Empty type '{s}'", .{key.asTypeName()});
                                    }

                                    try self.types.put(key.asTypeName(), info);
                                }
                            },
                            else => unreachable,
                        }

                        current = value.next;
                    } else {
                        self.hasError(node, "File has a mismatched number of keys and values", .{});
                        current = key.next;
                    }
                }

                // unused types
                var iter = self.types.iterator();
                while (iter.next()) |item| {
                    if (!item.value_ptr.used) {
                        self.hasError(item.value_ptr.node, "Unused type '{s}'", .{item.key_ptr.*});
                    }
                }
            },
            .list => {
                // validate items
                var current = node.asList().first;
                while (current) |cur| : (current = cur.next) {
                    try self.validateNode(cur, type_key_count);
                }
            },
            .map => {
                if (type_key_count) |key_count| {
                    var val_count: usize = 0;
                    var current = node.asMap().first;
                    while (current) |cur| : (current = cur.next) {
                        val_count += 1;
                        try self.validateNode(cur, null);
                    }

                    // number of values <= number of keys
                    if (val_count > key_count) {
                        self.hasError(node, "Typed map has more values than the type has keys", .{});
                    }
                } else {
                    var keys = std.StringHashMap(void).init(self.allocator);
                    defer keys.deinit();

                    var current = node.asMap().first;
                    while (current) |key| {
                        if (key.next) |value| {
                            // keys are unique
                            try self.validateKey(&keys, key);

                            // validate values
                            try self.validateNode(value, null);

                            current = value.next;
                        } else {
                            self.hasError(node, "Map has a mismatched number of keys and values", .{});
                            current = key.next;
                        }
                    }
                }
            },
            .typed => {
                const typed = node.asTyped();
                var key_count: ?usize = null;
                switch (typed.type.getType()) {
                    .discard => {}, // do nothing, count is already null
                    .map => {
                        var keys = std.StringHashMap(void).init(self.allocator);
                        defer keys.deinit();

                        var current = typed.type.asMap().first;
                        while (current) |key| : (current = key.next) {
                            // keys are unique
                            try self.validateKey(&keys, key);
                        }

                        // contains at least one key
                        if (keys.unmanaged.size < 1) {
                            self.hasError(typed.type, "Empty inline type", .{});
                        }

                        key_count = keys.unmanaged.size;
                    },
                    .type_name => {
                        // type is defined
                        const name = typed.type.asTypeName();
                        if (self.types.getPtr(name)) |type_ptr| {
                            type_ptr.used = true;
                            key_count = type_ptr.count;
                        } else {
                            self.hasError(typed.type, "Unknown type '{s}'", .{name});
                        }
                    },
                    else => unreachable,
                }

                try self.validateNode(typed.node, key_count);
            },
            else => {},
        }
    }
};
