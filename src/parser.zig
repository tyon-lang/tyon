const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const err = @import("error.zig");
const Lexer = @import("lexer.zig").Lexer;
const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;
const Token = @import("lexer.zig").Token;
const TokenType = @import("lexer.zig").TokenType;

const Comment = struct {
    value: []const u8,
    line: usize,
    next: ?*Comment,

    fn init(alloc: Allocator, val: []const u8, line_val: usize) *Comment {
        const new = alloc.create(Comment) catch {
            err.printExit("Could not allocate memory for comment.", .{}, 1);
        };
        new.* = .{
            .value = val,
            .line = line_val,
            .next = null,
        };
        return new;
    }
};

const ParseResult = struct {
    root: *Node,
    comments: ?*Comment,

    pub fn print(self: ParseResult) void {
        self.root.print(0);
        std.debug.print("comments\n", .{});
        var current = self.comments;
        while (current) |cur| : (current = cur.next) {
            std.debug.print("  [{d}] '{s}'\n", .{ cur.line + 1, cur.value });
        }
    }
};

pub const Parser = struct {
    allocator: Allocator,
    lexer: Lexer,
    include_comments: bool,

    current: Token,
    previous: Token,

    root: *Node,
    first_comment: ?*Comment,
    last_comment: ?*Comment,

    pub fn init(alloc: Allocator, source: []const u8, inc_comments: bool) !Parser {
        var new = Parser{
            .allocator = alloc,
            .lexer = Lexer.init(source),
            .include_comments = inc_comments,

            .root = undefined,
            .current = undefined,
            .previous = undefined,

            .first_comment = null,
            .last_comment = null,
        };

        try new.advance();
        return new;
    }

    pub fn deinit(self: *Parser) void {
        self.root.deinit(self.allocator);

        var current = self.first_comment;
        while (current) |curr| {
            current = curr.next;
            self.allocator.destroy(curr);
        }
    }

    fn errorAt(token: Token, message: []const u8) !void {
        if (token.type == .eof) {
            std.debug.print("[{d}, {d}]-[{d}, {d}] at end: {s}", .{
                token.start_line + 1,
                token.start_column + 1,
                token.end_line + 1,
                token.end_column + 1,
                message,
            });
        } else {
            std.debug.print("[{d}, {d}]-[{d}, {d}] at '{s}': {s}", .{
                token.start_line + 1,
                token.start_column + 1,
                token.end_line + 1,
                token.end_column + 1,
                token.value,
                message,
            });
        }
        return error.InvalidInput;
    }

    fn addComment(self: *Parser, val: []const u8, line: usize) void {
        const comment = Comment.init(self.allocator, val, line);
        if (self.last_comment) |l| {
            l.next = comment;
        } else {
            self.first_comment = comment;
        }
        self.last_comment = comment;
    }

    fn advance(self: *Parser) !void {
        self.previous = self.current;

        while (true) {
            self.current = try self.lexer.lexToken();
            if (self.current.type != .comment) break;

            if (self.include_comments) {
                self.addComment(self.current.value, self.current.start_line);
            }
        }
    }

    fn check(self: *Parser, expected: TokenType) bool {
        return self.current.type == expected;
    }

    fn match(self: *Parser, expected: TokenType) !bool {
        if (!self.check(expected)) return false;
        try self.advance();
        return true;
    }

    fn consume(self: *Parser, expected: TokenType, message: []const u8) !void {
        if (!self.check(expected)) {
            try errorAt(self.current, message);
        }
        try self.advance();
    }

    pub fn parse(self: *Parser) !ParseResult {
        self.root = Node.File(self.allocator);

        try self.parseFile(self.root.asFile());

        return .{ .root = self.root, .comments = self.first_comment };
    }

    fn parseFile(self: *Parser, parent: *NodeList) !void {
        while (!try self.match(.eof)) {
            if (try self.match(.left_paren)) {
                try self.parseTypedef(parent);
            } else {
                try self.parseKey(parent);
                try self.parseValue(parent, false, false);
            }
        }
    }

    fn parseKey(self: *Parser, parent: *NodeList) !void {
        if (try self.match(.string)) {
            parent.add(Node.String(self.allocator, self.previous));
        } else if (try self.match(.value)) {
            parent.add(Node.Value(self.allocator, self.previous));
        } else {
            try errorAt(self.current, "Only strings and values can be used as keys");
        }
    }

    fn parseList(self: *Parser, list: *Node, typed: bool) error{InvalidInput}!void {
        while (self.current.type != .right_bracket) {
            try self.parseValue(list.asList(), typed, typed);
        }
        try self.consume(.right_bracket, "Missing ]");

        list.end_line = self.previous.end_line;
        list.end_column = self.previous.end_column;
    }

    fn parseMap(self: *Parser, map: *Node, typed: bool) error{InvalidInput}!void {
        while (self.current.type != .right_paren) {
            if (!typed) try self.parseKey(map.asMap());
            try self.parseValue(map.asMap(), false, typed);
        }
        try self.consume(.right_paren, "Missing )");

        map.end_line = self.previous.end_line;
        map.end_column = self.previous.end_column;
    }

    fn parseTyped(self: *Parser, parent: *NodeList) !void {
        const typed = Node.Typed(self.allocator, self.previous);
        parent.add(typed);

        var is_typed = true;

        // type name or inline type
        if (try self.match(.left_paren)) {
            const inline_type = Node.Map(self.allocator, self.previous);
            typed.asTyped().type = inline_type;

            while (self.current.type != .right_paren) {
                try self.parseKey(inline_type.asMap());
            }
            try self.consume(.right_paren, "Missing )");

            inline_type.end_line = self.previous.end_line;
            inline_type.end_column = self.previous.end_column;
        } else if (try self.match(.value)) {
            typed.asTyped().type = Node.Value(self.allocator, self.previous);
        } else if (try self.match(.discard)) {
            typed.asTyped().type = Node.Discard(self.allocator, self.previous);
            is_typed = false;
        } else {
            try errorAt(self.current, "Type must be a value or inline type");
        }

        // value
        if (try self.match(.left_paren)) {
            const map = Node.Map(self.allocator, self.previous);
            typed.asTyped().node = map;
            try self.parseMap(map, is_typed);
        } else if (try self.match(.left_bracket)) {
            const list = Node.List(self.allocator, self.previous);
            typed.asTyped().node = list;
            try self.parseList(list, is_typed);
        } else {
            try errorAt(self.current, "Types can only be applied to lists and maps");
        }

        typed.end_line = self.previous.end_line;
        typed.end_column = self.previous.end_column;
    }

    fn parseTypedef(self: *Parser, parent: *NodeList) !void {
        const typedef = Node.Typedef(self.allocator, self.previous);
        parent.add(typedef);

        try self.consume(.slash, "A map cannot be used as a key");

        try self.consume(.value, "Type name must be a value");
        typedef.asTypedef().add(Node.Value(self.allocator, self.previous));

        while (self.current.type != .right_paren) {
            try self.parseKey(typedef.asTypedef());
        }
        try self.consume(.right_paren, "Missing )");

        typedef.end_line = self.previous.end_line;
        typedef.end_column = self.previous.end_column;
    }

    fn parseValue(self: *Parser, parent: *NodeList, typed_children: bool, allow_discard: bool) !void {
        if (try self.match(.left_paren)) {
            const map = Node.Map(self.allocator, self.previous);
            parent.add(map);
            try self.parseMap(map, typed_children);
        } else if (try self.match(.left_bracket)) {
            const list = Node.List(self.allocator, self.previous);
            parent.add(list);
            try self.parseList(list, typed_children);
        } else if (try self.match(.string)) {
            parent.add(Node.String(self.allocator, self.previous));
        } else if (try self.match(.value)) {
            parent.add(Node.Value(self.allocator, self.previous));
        } else if (try self.match(.discard)) {
            if (allow_discard) {
                parent.add(Node.Discard(self.allocator, self.previous));
            } else {
                try errorAt(self.previous, "A discard is only valid on typed maps");
            }
        } else if (try self.match(.slash)) {
            try self.parseTyped(parent);
        } else {
            try errorAt(self.current, "Not a valid value");
        }
    }
};
