const std = @import("std");
const Error = std.fs.File.WriteError;

const Comment = @import("parser.zig").Comment;
const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;
const ParseResult = @import("parser.zig").ParseResult;
const TypedNode = @import("tree.zig").TypedNode;

pub fn format(parse_result: ParseResult, output_writer: anytype) !void {
    const formatter = struct {
        const Self = @This();

        comment: ?*Comment,
        new_line: bool,
        prior_line: usize,
        writer: @TypeOf(output_writer),

        fn init(comment: ?*Comment, writer: @TypeOf(output_writer)) Self {
            return .{
                .comment = comment,
                .new_line = true,
                .prior_line = 0,
                .writer = writer,
            };
        }

        fn formatFile(self: *Self, file: *NodeList) !void {
            if (file.first) |_| {
                var current = file.first;
                var min: usize = 0;
                while (current) |key| {
                    if (key.next) |value| {
                        try self.formatNode(key, min, 2);
                        if (key.end_line == value.start_line) {
                            try self.writer.writeAll(" = ");
                        } else {
                            try self.writer.writeAll(" =");
                        }
                        try self.formatNode(value, 0, 1);
                        min = 1;
                        current = value.next;
                    } else {
                        current = key.next;
                    }
                }
            }
            try self.print("", .{}, std.math.maxInt(usize), std.math.maxInt(usize), 1, 1);
        }

        fn formatNode(self: *Self, node: *Node, min: usize, max: usize) !void {
            switch (node.getType()) {
                .discard => try self.write(node.asDiscard(), node.start_line, node.end_line, min, max),
                .file => unreachable,
                .list => {},
                .literal => try self.write(node.asLiteral(), node.start_line, node.end_line, min, max),
                .map => {},
                .string => try self.print("\"{s}\"", .{node.asString()}, node.start_line, node.end_line, min, max),
                .typed => {},
                .type_name => try self.print("/{s}", .{node.asTypeName()}, node.start_line, node.end_line, min, max),
            }
        }

        fn indent(self: *Self, indent_level: usize) !void {
            for (0..indent_level) |_| {
                try self.writer.writeAll("\t");
            }
        }

        fn print(self: *Self, comptime fmt: []const u8, args: anytype, start_line: usize, end_line: usize, min: usize, max: usize) !void {
            while (self.comment) |comment| : (self.comment = comment.next) {
                if (comment.line >= start_line) break;

                if (comment.line > self.prior_line + 1) {
                    try self.writer.writeAll("\n\n");
                    self.new_line = true;
                } else if (comment.line > self.prior_line) {
                    try self.writer.writeAll("\n");
                    self.new_line = true;
                }
                if (!self.new_line) try self.writer.writeAll(" ");
                try self.writer.print(";{s}", .{comment.value});

                self.prior_line = comment.line;
            }

            var count = std.math.min(start_line - self.prior_line, max);
            count = std.math.max(count, min);

            for (0..count) |_| {
                try self.writer.writeAll("\n");
            }

            try self.writer.print(fmt, args);

            self.new_line = false;
            self.prior_line = end_line;
        }

        fn write(self: *Self, bytes: []const u8, start_line: usize, end_line: usize, min: usize, max: usize) !void {
            try self.print("{s}", .{bytes}, start_line, end_line, min, max);
        }
    };

    var fmt = formatter.init(parse_result.comments, output_writer);
    try fmt.formatFile(parse_result.root.asFile());
}
