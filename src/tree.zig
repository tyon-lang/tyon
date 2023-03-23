const std = @import("std");
const Allocator = std.mem.Allocator;

const err = @import("error.zig");
const Token = @import("lexer.zig").Token;

const NodeType = enum {
    file,
    list,
    map,
    string,
    value,
};

pub const NodeList = struct {
    first: ?*Node,
    last: ?*Node,

    pub fn init() NodeList {
        return .{ .first = null, .last = null };
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

pub const Node = struct {
    as: union(NodeType) {
        file: NodeList,
        list: NodeList,
        map: NodeList,
        string: []const u8,
        value: []const u8,
    },
    start_line: usize,
    start_column: usize,
    end_line: usize,
    end_column: usize,
    next: ?*Node,

    pub fn File(alloc: Allocator) *Node {
        const new = alloc.create(Node) catch {
            err.printExit("Could not allocate memory for node.", .{}, 1);
        };
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

    pub fn List(alloc: Allocator, token: Token) *Node {
        const new = alloc.create(Node) catch {
            err.printExit("Could not allocate memory for node.", .{}, 1);
        };
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

    pub fn Map(alloc: Allocator, token: Token) *Node {
        const new = alloc.create(Node) catch {
            err.printExit("Could not allocate memory for node.", .{}, 1);
        };
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

    pub fn String(alloc: Allocator, token: Token) *Node {
        const new = alloc.create(Node) catch {
            err.printExit("Could not allocate memory for node.", .{}, 1);
        };
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

    pub fn Value(alloc: Allocator, token: Token) *Node {
        const new = alloc.create(Node) catch {
            err.printExit("Could not allocate memory for node.", .{}, 1);
        };
        new.* = .{
            .as = .{ .value = token.value },
            .start_line = token.start_line,
            .start_column = token.start_column,
            .end_line = token.end_line,
            .end_column = token.end_column,
            .next = null,
        };
        return new;
    }

    pub fn getType(self: Node) NodeType {
        return self.as;
    }

    pub fn asFile(self: *Node) *NodeList {
        return &self.as.file;
    }

    pub fn asList(self: *Node) *NodeList {
        return &self.as.list;
    }

    pub fn asMap(self: *Node) *NodeList {
        return &self.as.map;
    }

    pub fn asString(self: Node) []const u8 {
        return self.as.string;
    }

    pub fn asValue(self: Node) []const u8 {
        return self.as.value;
    }

    pub fn print(self: *Node, indent: usize) void {
        printIndent(indent);
        switch (self.getType()) {
            .file => {
                std.debug.print("file\n", .{});
                var current = self.asFile().first;
                while (current) |cur| : (current = cur.next) {
                    cur.print(indent + 1);
                }
            },
            .list => {
                std.debug.print("list\n", .{});
                var current = self.asList().first;
                while (current) |cur| : (current = cur.next) {
                    cur.print(indent + 1);
                }
            },
            .map => {
                std.debug.print("map\n", .{});
                var current = self.asMap().first;
                while (current) |cur| : (current = cur.next) {
                    cur.print(indent + 1);
                }
            },
            .string => std.debug.print("string '{s}'\n", .{self.asString()}),
            .value => std.debug.print("value '{s}'\n", .{self.asValue()}),
        }
    }

    fn printIndent(indent: usize) void {
        for (0..indent) |_| {
            std.debug.print("  ", .{});
        }
    }
};
