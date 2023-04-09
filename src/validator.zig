const std = @import("std");

const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;

pub const Validator = struct {
    pub fn validate(root: *Node) !void {
        _ = root;
        // todo
    }
};
