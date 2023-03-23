const std = @import("std");

const err = @import("error.zig");

pub const TokenType = enum {
    left_paren,
    right_paren,
    left_bracket,
    right_bracket,
    slash,
    comment,
    string,
    value,
    eof,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
    line: usize,
    column: usize,
};

pub const Lexer = struct {
    source: []const u8,
    line: usize,
    column: usize,
    start_index: usize,
    current_index: usize,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .line = 0,
            .column = 0,
            .start_index = 0,
            .current_index = 0,
        };
    }

    pub fn isAtEnd(self: *Lexer) bool {
        return self.current_index >= self.source.len;
    }

    fn incrLine(self: *Lexer) void {
        self.line += 1;
        self.column = 0;
    }

    fn advance(self: *Lexer) void {
        self.current_index += 1;
        self.column += 1;
        if (self.isAtEnd()) self.current_index = self.source.len;
    }

    fn peek(self: *Lexer, offset: usize) u8 {
        const index = self.current_index + offset;
        return if (index < self.source.len) self.source[index] else 0;
    }

    fn resetLength(self: *Lexer) void {
        self.start_index = self.current_index;
    }

    fn token(self: *Lexer, token_type: TokenType) Token {
        return .{
            .type = token_type,
            .value = self.source[self.start_index..self.current_index],
            .line = self.line,
            .column = self.column + self.start_index - self.current_index,
        };
    }

    fn isValue(c: u8) bool {
        return switch (c) {
            ' ', '\t', '\r', '\n', '(', ')', '[', ']', 0 => false,
            else => true,
        };
    }

    fn comment(self: *Lexer) Token {
        // discard ;
        self.resetLength();
        while (self.peek(0) != '\n' and !self.isAtEnd()) self.advance();
        return self.token(.comment);
    }

    fn string(self: *Lexer) Token {
        // discard opening quote
        self.resetLength();

        while (self.peek(0) != '"' and self.peek(0) != '\n' and !self.isAtEnd()) {
            if (self.peek(0) == '\\' and self.peek(1) != 0) self.advance();
            self.advance();
        }

        if (self.isAtEnd() or self.peek(0) != '"') {
            // the extra 1 in column and size is to include the starting "
            err.errorAt(
                "Unterminated string",
                self.line,
                self.column + self.start_index - self.current_index - 1,
                self.current_index + 1 - self.start_index,
                .{},
                65,
            );
        }

        const tok = self.token(.string);

        // discard closing quote
        self.advance();
        self.resetLength();

        return tok;
    }

    fn value(self: *Lexer) Token {
        while (isValue(self.peek(0))) self.advance();
        return self.token(.value);
    }

    pub fn lexToken(self: *Lexer) Token {
        self.resetLength();

        while (!self.isAtEnd()) {
            const c = self.peek(0);
            self.advance();

            switch (c) {
                ' ', '\t', '\r' => self.resetLength(),
                '\n' => {
                    self.incrLine();
                    self.resetLength();
                },
                '(' => return self.token(.left_paren),
                ')' => return self.token(.right_paren),
                '[' => return self.token(.left_bracket),
                ']' => return self.token(.right_bracket),
                '/' => return self.token(.slash),
                ';' => return self.comment(),
                '"' => return self.string(),
                else => return self.value(),
            }
        }

        return self.token(.eof);
    }
};
