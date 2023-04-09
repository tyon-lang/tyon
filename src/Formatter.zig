const std = @import("std");
const Error = std.fs.File.WriteError;

const Comment = @import("parser.zig").Comment;
const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;
const ParseResult = @import("parser.zig").ParseResult;

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
                        if (key.getType() == .type_name) {
                            try self.write("/", key.start_line, key.start_line, min, 2, 0);
                            try self.formatNode(key, 0, 0, 0, false);
                        } else {
                            try self.formatNode(key, min, 2, 0, false);
                        }
                        if (key.end_line == value.start_line) {
                            try self.writer.writeAll(" = ");
                        } else {
                            try self.writer.writeAll(" =");
                        }

                        try self.formatNode(value, 0, 1, 0, key.getType() == .type_name);

                        min = 1;
                        current = value.next;
                    } else {
                        current = key.next;
                    }
                }
            }
            try self.print("", .{}, std.math.maxInt(usize), std.math.maxInt(usize), 1, 1, 0);
        }

        fn formatIndent(self: *Self, indent: usize) !void {
            for (0..indent) |_| {
                try self.writer.writeAll("\t");
            }
        }

        fn formatList(self: *Self, list: *Node, min: usize, max: usize, indent: usize, typed: bool) !void {
            try self.formatListHelper(list, list.asList().first, min, max, indent, typed, "[", "]");
        }

        fn formatListHelper(self: *Self, node: *Node, first_item: ?*Node, min: usize, max: usize, indent: usize, typed: bool, start_tok: []const u8, end_tok: []const u8) !void {
            try self.write(start_tok, node.start_line, node.start_line, min, max, indent);
            if (node.start_line == node.end_line) {
                var current = first_item;
                while (current) |cur| : (current = cur.next) {
                    if (current != first_item) {
                        try self.writer.writeAll(" ");
                    }
                    try self.formatNode(cur, 0, 0, indent, typed);
                }
                try self.writer.writeAll(end_tok);
            } else {
                if (first_item) |first| {
                    try self.formatNode(first, 1, 1, indent + 1, typed);
                    var prior_line = first.end_line;
                    var current = first.next;
                    while (current) |cur| : (current = cur.next) {
                        if (prior_line == cur.start_line) try self.writer.writeAll(" ");
                        try self.formatNode(cur, 0, 2, indent + 1, typed);
                        prior_line = cur.end_line;
                    }
                }
                try self.write(end_tok, node.end_line, node.end_line, 1, 1, indent);
            }
        }

        fn formatMap(self: *Self, map: *Node, min: usize, max: usize, indent: usize, typed: bool) !void {
            if (typed) {
                try self.formatListHelper(map, map.asMap().first, min, max, indent, false, "(", ")");
            } else {
                try self.write("(", map.start_line, map.start_line, min, max, indent);
                if (map.start_line == map.end_line) {
                    const first_item = map.asMap().first;
                    var current = first_item;
                    while (current) |key| {
                        if (key.next) |value| {
                            if (current != first_item) {
                                try self.writer.writeAll(" ");
                            }
                            try self.formatNode(key, 0, 0, indent, false);
                            try self.writer.writeAll(" = ");
                            try self.formatNode(value, 0, 0, indent, false);
                            current = value.next;
                        } else {
                            current = key.next;
                        }
                    }
                    try self.writer.writeAll(")");
                } else {
                    if (map.asMap().first) |first_key| {
                        if (first_key.next) |first_val| {
                            try self.formatNode(first_key, 1, 1, indent + 1, false);
                            if (first_key.end_line == first_val.start_line) {
                                try self.writer.writeAll(" = ");
                            } else {
                                try self.writer.writeAll(" =");
                            }
                            try self.formatNode(first_val, 0, 1, indent + 1, false);

                            var current = first_val.next;
                            while (current) |key| {
                                if (key.next) |value| {
                                    try self.formatNode(key, 1, 2, indent + 1, false);
                                    if (key.end_line == value.start_line) {
                                        try self.writer.writeAll(" = ");
                                    } else {
                                        try self.writer.writeAll(" =");
                                    }
                                    try self.formatNode(value, 0, 1, indent + 1, false);
                                    current = value.next;
                                } else {
                                    current = key.next;
                                }
                            }
                        }
                    }
                    try self.write(")", map.end_line, map.end_line, 1, 1, indent);
                }
            }
        }

        fn formatNode(self: *Self, node: *Node, min: usize, max: usize, indent: usize, typed: bool) Error!void {
            switch (node.getType()) {
                .discard => try self.write(node.asDiscard(), node.start_line, node.end_line, min, max, indent),
                .file => unreachable,
                .list => try self.formatList(node, min, max, indent, typed),
                .literal => try self.write(node.asLiteral(), node.start_line, node.end_line, min, max, indent),
                .map => try self.formatMap(node, min, max, indent, typed),
                .string => try self.print("\"{s}\"", .{node.asString()}, node.start_line, node.end_line, min, max, indent),
                .typed => try self.formatTyped(node, min, max, indent),
                .type_name => try self.write(node.asTypeName(), node.start_line, node.end_line, min, max, indent),
            }
        }

        fn formatTyped(self: *Self, typed_node: *Node, min: usize, max: usize, indent: usize) !void {
            const typed = typed_node.asTyped();
            try self.write("/", typed.type.start_line, typed.type.start_line, min, max, indent);
            try self.formatNode(typed.type, 0, 0, indent, true);
            if (typed.type.end_line == typed.node.start_line) {
                try self.writer.writeAll(" ");
            }
            try self.formatNode(typed.node, 0, 1, indent, typed.type.getType() != .discard);
        }

        fn print(self: *Self, comptime fmt: []const u8, args: anytype, start_line: usize, end_line: usize, min: usize, max: usize, indent: usize) !void {
            while (self.comment) |comment| : (self.comment = comment.next) {
                if (comment.line >= start_line) break;

                if (comment.line > self.prior_line + 1) {
                    try self.writer.writeAll("\n\n");
                    self.new_line = true;
                } else if (comment.line > self.prior_line) {
                    try self.writer.writeAll("\n");
                    self.new_line = true;
                }
                if (!self.new_line) {
                    try self.writer.writeAll(" ");
                } else {
                    try self.formatIndent(indent);
                }
                try self.writer.print(";{s}", .{comment.value});

                self.prior_line = comment.line;
            }

            var count = std.math.min(start_line - self.prior_line, max);
            count = std.math.max(count, min);

            for (0..count) |_| {
                try self.writer.writeAll("\n");
            }

            if (count > 0) try self.formatIndent(indent);
            try self.writer.print(fmt, args);

            self.new_line = false;
            self.prior_line = end_line;
        }

        fn write(self: *Self, bytes: []const u8, start_line: usize, end_line: usize, min: usize, max: usize, indent: usize) !void {
            try self.print("{s}", .{bytes}, start_line, end_line, min, max, indent);
        }
    };

    var fmt = formatter.init(parse_result.comments, output_writer);
    try fmt.formatFile(parse_result.root.asFile());
}
