const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;

const TypeInfo = struct {
    count: usize,
    used: bool,

    fn init() TypeInfo {
        return .{
            .count = 0,
            .used = false,
        };
    }
};

pub const Validator = struct {
    allocator: Allocator,
    has_error: bool,
    types: std.StringHashMap(TypeInfo),

    fn init(alloc: Allocator) Validator {
        return .{
            .allocator = alloc,
            .has_error = false,
            .types = std.StringHashMap(TypeInfo).init(alloc),
        };
    }

    fn deinit(self: *Validator) void {
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

        try validator.validateNode(root);

        if (validator.has_error) {
            return error.Semantics;
        } else {
            std.debug.print("  Success\n", .{});
        }
    }

    fn validateNode(self: *Validator, node: *Node) !void {
        switch (node.getType()) {
            .file => {
                // todo - typedef contains at least 1 key
                // todo - find unused typedefs

                // keys are unique
                var keys = std.StringHashMap(void).init(self.allocator);
                defer keys.deinit();

                var current = node.asFile().first;
                while (current) |key| {
                    if (key.next) |value| {
                        switch (key.getType()) {
                            .literal => {
                                // todo - check for dupes in the key map
                            },
                            .string => {
                                // todo - unescape quotes and check for dupes in the keys map
                            },
                            .type_name => {
                                // type names are unique
                                if (self.types.contains(key.asTypeName())) {
                                    self.hasError(key, "Duplicate type '{s}'", .{key.asTypeName()});
                                } else {
                                    try self.types.put(key.asTypeName(), TypeInfo.init());
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
            },
            .list => {
                // check children
                var current = node.asList().first;
                while (current) |cur| : (current = cur.next) {
                    try self.validateNode(cur);
                }
            },
            .map => {
                // todo - map keys are unique
            },
            .typed => {
                // todo - type
                // todo -   named
                // todo -     type is defined
                // todo -   inline
                // todo -     keys are unique
                // todo -     contains at least 1 key
                // todo - node
                // todo -   map
                // todo -     number of values <= number of keys
            },
            else => {},
        }
    }
};
