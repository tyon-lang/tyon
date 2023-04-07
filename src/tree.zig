const std = @import("std");
const Allocator = std.mem.Allocator;

const Token = @import("lexer.zig").Token;

const NodeType = enum {
    discard,
    file,
    list,
    literal,
    map,
    string,
    typed,
    type_name,
};

pub const NodeList = struct {
    first: ?*Node,
    last: ?*Node,

    pub fn init() NodeList {
        return .{ .first = null, .last = null };
    }

    pub fn deinit(self: NodeList, alloc: Allocator) void {
        var current = self.first;
        while (current) |curr| {
            current = curr.next;
            alloc.destroy(curr);
        }
    }

    pub fn add(self: *NodeList, node: *Node) void {
        if (self.last) |l| {
            l.next = node;
        } else {
            self.first = node;
        }
        self.last = node;
    }
};

pub const TypedNode = struct {
    type: *Node,
    node: *Node,
};

pub const Node = struct {
    as: union(NodeType) {
        discard: []const u8,
        file: NodeList,
        list: NodeList,
        literal: []const u8,
        map: NodeList,
        string: []const u8,
        typed: TypedNode,
        type_name: []const u8,
    },
    start_line: usize,
    start_column: usize,
    end_line: usize,
    end_column: usize,
    next: ?*Node,

    pub fn Discard(alloc: Allocator, token: Token) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .discard = token.value },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn File(alloc: Allocator) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .file = NodeList.init() },
            .start_line = 0,
            .start_column = 0,
            .end_line = 0,
            .end_column = 0,
            .next = null,
        };
        return new;
    }

    pub fn List(alloc: Allocator, token: Token) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .list = NodeList.init() },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn Literal(alloc: Allocator, token: Token) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .literal = token.value },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn Map(alloc: Allocator, token: Token) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .map = NodeList.init() },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn String(alloc: Allocator, token: Token) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .string = token.value },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn Typed(alloc: Allocator, token: Token) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .typed = undefined },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn TypeName(alloc: Allocator, token: Token) !*Node {
        const new = try alloc.create(Node);
        new.* = .{
            .as = .{ .type_name = token.value },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn deinit(self: *Node, alloc: Allocator) void {
        switch (self.getType()) {
            .file => self.asFile().deinit(alloc),
            .list => self.asList().deinit(alloc),
            .map => self.asMap().deinit(alloc),
            .typed => {
                self.asTyped().type.deinit(alloc);
                self.asTyped().node.deinit(alloc);
            },
            else => {},
        }
        alloc.destroy(self);
    }

    pub fn getType(self: Node) NodeType {
        return self.as;
    }

    pub fn asDiscard(self: Node) []const u8 {
        return self.as.discard;
    }

    pub fn asFile(self: *Node) *NodeList {
        return &self.as.file;
    }

    pub fn asList(self: *Node) *NodeList {
        return &self.as.list;
    }

    pub fn asLiteral(self: Node) []const u8 {
        return self.as.literal;
    }

    pub fn asMap(self: *Node) *NodeList {
        return &self.as.map;
    }

    pub fn asString(self: Node) []const u8 {
        return self.as.string;
    }

    pub fn asTyped(self: *Node) *TypedNode {
        return &self.as.typed;
    }

    pub fn asTypeName(self: Node) []const u8 {
        return self.as.type_name;
    }

    pub fn number(self: *Node) ?f64 {
        if (self.getType() != .literal) return null;
        var val = self.asLiteral();
        const negative = val[0] == '-';
        if (negative) val = val[1..];

        var radix: u8 = 10;
        if (val.len >= 2 and val[0] == '0') {
            switch (val[1]) {
                'b', 'B' => {
                    val = val[2..];
                    radix = 2;
                },
                'o', 'O' => {
                    val = val[2..];
                    radix = 8;
                },
                'x', 'X' => {
                    val = val[2..];
                    radix = 16;
                },
                else => {},
            }
        }

        var prior_was_digit = false;
        var has_fractional_part = false;
        var whole: usize = 0;
        var numerator: usize = 0;
        var denominator: usize = 1;
        for (val) |c| {
            switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    const digit = switch (c) {
                        '0'...'9' => c - '0',
                        'a'...'f' => c - 'a' + 10,
                        'A'...'F' => c - 'A' + 10,
                        else => return null,
                    };

                    if (digit >= radix) return null;

                    if (!has_fractional_part) {
                        whole *= radix;
                        whole += digit;
                    } else {
                        numerator *= radix;
                        numerator += digit;
                        denominator *= radix;
                    }

                    prior_was_digit = true;
                },
                '.' => {
                    if (!prior_was_digit) return null;
                    if (has_fractional_part) return null;

                    has_fractional_part = true;
                    prior_was_digit = false;
                },
                '_' => {
                    if (!prior_was_digit) return null;

                    prior_was_digit = false;
                },
                else => return null,
            }
        }

        if (!prior_was_digit) return null;

        var result = @intToFloat(f64, whole);
        if (has_fractional_part) {
            result += @intToFloat(f64, numerator) / @intToFloat(f64, denominator);
        }
        if (negative) result *= -1;

        return result;
    }

    pub fn print(self: *Node, indent: usize) void {
        printIndent(indent);
        switch (self.getType()) {
            .discard => std.debug.print("discard '{s}'\n", .{self.asDiscard()}),
            .file => {
                std.debug.print("file\n", .{});
                var current = self.asFile().first;
                while (current) |cur| : (current = cur.next) {
                    cur.print(indent + 1);
                }
            },
            .list => {
                std.debug.print("list [{d}, {d}]-[{d}, {d}]\n", .{
                    self.start_line + 1,
                    self.start_column + 1,
                    self.end_line + 1,
                    self.end_column + 1,
                });
                var current = self.asList().first;
                while (current) |cur| : (current = cur.next) {
                    cur.print(indent + 1);
                }
            },
            .literal => std.debug.print("literal '{s}'\n", .{self.asLiteral()}),
            .map => {
                std.debug.print("map [{d}, {d}]-[{d}, {d}]\n", .{
                    self.start_line + 1,
                    self.start_column + 1,
                    self.end_line + 1,
                    self.end_column + 1,
                });
                var current = self.asMap().first;
                while (current) |cur| : (current = cur.next) {
                    cur.print(indent + 1);
                }
            },
            .string => std.debug.print("string '{s}'\n", .{self.asString()}),
            .typed => {
                std.debug.print("typed [{d}, {d}]-[{d}, {d}]\n", .{
                    self.start_line + 1,
                    self.start_column + 1,
                    self.end_line + 1,
                    self.end_column + 1,
                });
                self.asTyped().type.print(indent + 1);
                self.asTyped().node.print(indent + 1);
            },
            .type_name => std.debug.print("type name '{s}'\n", .{self.asTypeName()}),
        }
    }

    fn printIndent(indent: usize) void {
        for (0..indent) |_| {
            std.debug.print("  ", .{});
        }
    }
};
