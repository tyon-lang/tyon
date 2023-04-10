const std = @import("std");
const Error = error{Validation};

const Node = @import("tree.zig").Node;
const NodeList = @import("tree.zig").NodeList;

pub const Validator = struct {
    pub fn validate(root: *Node) !void {
        _ = root;

        // file
        //   items
        //     keys are unique
        //   typedef
        //     type names are unique
        //     contains at least 1 key
        //     unused typedefs

        // map
        //   keys are unique

        // typed
        //   type
        //     named
        //       type is defined
        //     inline
        //       keys are unique
        //       contains at least 1 key
        //   node
        //     map
        //       number of values <= number of keys
    }
};
