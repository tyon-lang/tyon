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
    arena: ArenaAllocator,
    allocator: Allocator,
    lexer: Lexer,
    include_comments: bool,

    current: Token,
    previous: Token,

    first_comment: ?*Comment,
    last_comment: ?*Comment,

    pub fn init(self: *Parser, alloc: Allocator, source: []const u8, inc_comments: bool) void {
        self.arena = ArenaAllocator.init(alloc);
        self.allocator = self.arena.allocator();
        self.lexer = Lexer.init(source);
        self.include_comments = inc_comments;

        self.first_comment = null;
        self.last_comment = null;

        self.advance();
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }

    fn errorAt(token: Token, message: []const u8) void {
        if (token.type == .eof) {
            err.errorAt("at end: {s}", token.start_line, token.start_column, token.end_line, token.end_column, .{message}, 65);
        } else {
            err.errorAt("at '{s}': {s}", token.start_line, token.start_column, token.end_line, token.end_column, .{ token.value, message }, 65);
        }
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

    fn advance(self: *Parser) void {
        self.previous = self.current;

        while (true) {
            self.current = self.lexer.lexToken();
            if (self.current.type != .comment) break;

            if (self.include_comments) {
                self.addComment(self.current.value, self.current.start_line);
            }
        }
    }

    fn check(self: *Parser, expected: TokenType) bool {
        return self.current.type == expected;
    }

    fn match(self: *Parser, expected: TokenType) bool {
        if (!self.check(expected)) return false;
        self.advance();
        return true;
    }

    fn consume(self: *Parser, expected: TokenType, message: []const u8) void {
        if (!self.check(expected)) {
            errorAt(self.current, message);
        }
        self.advance();
    }

    pub fn parse(self: *Parser) ParseResult {
        const file = Node.File(self.allocator);

        self.parseFile(file.asFile());

        return .{ .root = file, .comments = self.first_comment };
    }

    fn parseFile(self: *Parser, parent: *NodeList) void {
        while (!self.match(.eof)) {
            if (self.match(.left_paren)) {
                self.parseTypedef(parent);
            } else {
                self.parseKey(parent);
                self.parseValue(parent, false);
            }
        }
    }

    fn parseKey(self: *Parser, parent: *NodeList) void {
        if (self.match(.string)) {
            parent.add(Node.String(self.allocator, self.previous));
        } else if (self.match(.value)) {
            parent.add(Node.Value(self.allocator, self.previous));
        } else {
            errorAt(self.current, "Only strings and values can be used as a key");
        }
    }

    fn parseList(self: *Parser, list: *Node, typed: bool) void {
        while (self.current.type != .right_bracket) {
            self.parseValue(list.asList(), typed);
        }
        self.consume(.right_bracket, "Missing ]");

        list.end_line = self.previous.end_line;
        list.end_column = self.previous.end_column;
    }

    fn parseMap(self: *Parser, map: *Node, typed: bool) void {
        while (self.current.type != .right_paren) {
            if (!typed) self.parseKey(map.asMap());
            self.parseValue(map.asMap(), false);
        }
        self.consume(.right_paren, "Missing )");

        map.end_line = self.previous.end_line;
        map.end_column = self.previous.end_column;
    }

    fn parseTyped(self: *Parser, parent: *NodeList) void {
        const typed = Node.Typed(self.allocator, self.previous);
        parent.add(typed);

        var is_typed = true;

        // type name or inline type
        if (self.match(.left_paren)) {
            const inline_type = Node.Map(self.allocator, self.previous);
            typed.asTyped().type = inline_type;

            while (self.current.type != .right_paren) {
                self.parseKey(inline_type.asMap());
            }
            self.consume(.right_paren, "Missing )");

            inline_type.end_line = self.previous.end_line;
            inline_type.end_column = self.previous.end_column;
        } else if (self.match(.string)) {
            typed.asTyped().type = Node.String(self.allocator, self.previous);
        } else if (self.match(.value)) {
            typed.asTyped().type = Node.Value(self.allocator, self.previous);
        } else if (self.match(.discard)) {
            typed.asTyped().type = Node.Discard(self.allocator, self.previous);
            is_typed = false;
        } else {
            errorAt(self.current, "Type must be a string, value, or inline type");
        }

        // value
        if (self.match(.left_paren)) {
            const map = Node.Map(self.allocator, self.previous);
            typed.asTyped().node = map;
            self.parseMap(map, is_typed);
        } else if (self.match(.left_bracket)) {
            const list = Node.List(self.allocator, self.previous);
            typed.asTyped().node = list;
            self.parseList(list, is_typed);
        } else {
            errorAt(self.current, "Types can only be applied to lists and maps");
        }

        typed.end_line = self.previous.end_line;
        typed.end_column = self.previous.end_column;
    }

    fn parseTypedef(self: *Parser, parent: *NodeList) void {
        const typedef = Node.Typedef(self.allocator, self.previous);
        parent.add(typedef);

        self.consume(.slash, "A map cannot be used as a key");
        while (self.current.type != .right_paren) {
            self.parseKey(typedef.asTypedef());
        }
        self.consume(.right_paren, "Missing )");

        typedef.end_line = self.previous.end_line;
        typedef.end_column = self.previous.end_column;
    }

    fn parseValue(self: *Parser, parent: *NodeList, typed: bool) void {
        if (self.match(.left_paren)) {
            const map = Node.Map(self.allocator, self.previous);
            parent.add(map);
            self.parseMap(map, typed);
        } else if (self.match(.left_bracket)) {
            const list = Node.List(self.allocator, self.previous);
            parent.add(list);
            self.parseList(list, typed);
        } else if (self.match(.string)) {
            parent.add(Node.String(self.allocator, self.previous));
        } else if (self.match(.value)) {
            parent.add(Node.Value(self.allocator, self.previous));
        } else if (self.match(.discard)) {
            parent.add(Node.Discard(self.allocator, self.previous));
        } else if (self.match(.slash)) {
            self.parseTyped(parent);
        } else {
            errorAt(self.current, "Not a valid value");
        }
    }
};
