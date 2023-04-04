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
        writer: @TypeOf(output_writer),

        fn init(comment: ?*Comment, writer: @TypeOf(output_writer)) Self {
            return .{
                .comment = comment,
                .writer = writer,
            };
        }

        fn formatFile(self: *Self, file: *NodeList) !void {
            _ = file;
            _ = self;
        }
    };

    var fmt = formatter.init(parse_result.comments, output_writer);
    try fmt.formatFile(parse_result.root.asFile());
}
