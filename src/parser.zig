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
            std.debug.print("  [{d}] '{s}'\n", .{ cur.line, cur.value });
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

    fn error_(self: *Parser, message: []const u8) void {
        errorAt(self.previous, message);
    }

    fn errorAtCurrent(self: *Parser, message: []const u8) void {
        errorAt(self.current, message);
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
            self.errorAtCurrent(message);
        }
        self.advance();
    }

    fn fileItem(self: *Parser, parent: *NodeList) void {
        // typedef
        if (self.match(.left_paren)) {
            self.typedef(parent);
            return;
        }

        if (!self.match(.eof)) {
            self.key(parent);
            self.value(parent);
        }
    }

    fn key(self: *Parser, parent: *NodeList) void {
        if (self.match(.string)) {
            parent.add(Node.String(self.allocator, self.previous));
        } else if (self.match(.value)) {
            parent.add(Node.Value(self.allocator, self.previous));
        } else {
            self.errorAtCurrent("Only strings and values can be used as a key");
        }
    }

    fn typedef(self: *Parser, parent: *NodeList) void {
        self.consume(.slash, "A map cannot be used as a key");

        while (self.current.type != .right_paren and self.current.type != .eof) {
            self.key(parent);
        }
        self.consume(.right_paren, "Missing )");
    }

    fn value(self: *Parser, parent: *NodeList) void {
        if (self.match(.left_paren)) {
            // todo - map
        } else if (self.match(.left_bracket)) {
            // todo - list
        } else if (self.match(.string)) {
            parent.add(Node.String(self.allocator, self.previous));
        } else if (self.match(.value)) {
            parent.add(Node.Value(self.allocator, self.previous));
        } else {
            self.errorAtCurrent("Not a valid value");
        }
    }

    pub fn parse(self: *Parser) ParseResult {
        var file = Node.File(self.allocator);

        while (!self.match(.eof)) {
            self.fileItem(file.asFile());
        }

        return .{ .root = file, .comments = self.first_comment };
    }

    // fn parseHelper(self: *Parser, parent_node: *Node, parent: *ArrayList(Node)) !void {
    //     while (true) {
    //         const tok = self.lexer.lexToken();
    //         switch (tok.type) {
    //             .left_paren => {
    //                 var map = Node.Map(self.allocator, tok.line, tok.column);
    //                 try self.parseHelper(&map, map.asMap());
    //                 try parent.append(map);
    //             },
    //             .right_paren => {
    //                 if (!parent_node.isMap()) {
    //                     // todo - error
    //                 }
    //                 parent_node.end_line = tok.line;
    //                 parent_node.end_column = tok.column + tok.value.len;
    //                 return;
    //             },
    //             .left_bracket => {
    //                 var list = Node.List(self.allocator, tok.line, tok.column);
    //                 try self.parseHelper(&list, list.asList());
    //                 try parent.append(list);
    //             },
    //             .right_bracket => {
    //                 if (!parent_node.isList()) {
    //                     // todo - error
    //                 }
    //                 parent_node.end_line = tok.line;
    //                 parent_node.end_column = tok.column + tok.value.len;
    //                 return;
    //             },
    //             .slash => {
    //                 // todo - types
    //             },
    //             .comment => {
    //                 const val = self.copyString(tok.value);
    //                 const node = Node.Comment(val, tok.line, tok.column);
    //                 try parent.append(node);
    //             },
    //             .string => {
    //                 const val = self.copyString(tok.value);
    //                 const node = Node.String(val, tok.line, tok.column);
    //                 try parent.append(node);
    //             },
    //             .value => {
    //                 const val = self.copyString(tok.value);
    //                 const node = Node.Value(val, tok.line, tok.column);
    //                 try parent.append(node);
    //             },
    //             else => return,
    //         }
    //     }
    // }
};
