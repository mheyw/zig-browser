const std = @import("std");
const errors = @import("../errors.zig");
const BrowserError = errors.BrowserError;
const ErrorReporter = errors.ErrorReporter;

fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub const NodeType = enum {
    Element,
    Text,
    Document,
    Comment,
};

pub const ElementData = struct {
    tag_name: []const u8,
    attributes: std.StringHashMap([]const u8),
};

pub const Node = struct {
    node_type: NodeType,
    children: std.ArrayList(*Node),
    parent: ?*Node,
    allocator: std.mem.Allocator,
    error_reporter: *ErrorReporter,

    data: union(NodeType) {
        Element: ElementData,
        Text: []const u8,
        Document: void,
        Comment: []const u8,
    },

    pub fn createElement(allocator: std.mem.Allocator, error_reporter: *ErrorReporter, tag_name: []const u8) !*Node {
        debugPrint("Creating Element node. tag_name='{s}'\n", .{tag_name});

        if (tag_name.len == 0) {
            try error_reporter.report(BrowserError.InvalidNodeType, "Empty tag name", null, null);
            return BrowserError.InvalidNodeType;
        }

        const node = try allocator.create(Node);
        debugPrint("Allocated node at {*}\n", .{node});
        errdefer {
            debugPrint("Error occurred - freeing node at {*}\n", .{node});
            allocator.destroy(node);
        }

        const tag_name_copy = try allocator.dupe(u8, tag_name);
        debugPrint("Allocated tag_name copy at {*} = '{s}'\n", .{ tag_name_copy.ptr, tag_name_copy });
        errdefer {
            debugPrint("Error occurred - freeing tag_name at {*}\n", .{tag_name_copy.ptr});
            allocator.free(tag_name_copy);
        }

        node.* = Node{
            .node_type = .Element,
            .children = std.ArrayList(*Node).init(allocator),
            .parent = null,
            .allocator = allocator,
            .error_reporter = error_reporter,
            .data = .{
                .Element = ElementData{
                    .tag_name = tag_name_copy,
                    .attributes = std.StringHashMap([]const u8).init(allocator),
                },
            },
        };
        debugPrint("Successfully created Element node at {*}\n", .{node});
        return node;
    }

    pub fn createText(allocator: std.mem.Allocator, error_reporter: *ErrorReporter, text: []const u8) !*Node {
        debugPrint("Creating Text node. content='{s}'\n", .{text});

        if (text.len == 0) {
            try error_reporter.report(BrowserError.InvalidNodeType, "Empty text content", null, null);
            return BrowserError.InvalidNodeType;
        }

        const node = try allocator.create(Node);
        debugPrint("Allocated node at {*}\n", .{node});
        errdefer {
            debugPrint("Error occurred - freeing node at {*}\n", .{node});
            allocator.destroy(node);
        }

        const text_copy = try allocator.dupe(u8, text);
        debugPrint("Allocated text copy at {*} = '{s}'\n", .{ text_copy.ptr, text_copy });
        errdefer {
            debugPrint("Error occurred - freeing text at {*}\n", .{text_copy.ptr});
            allocator.free(text_copy);
        }

        node.* = Node{
            .node_type = .Text,
            .children = std.ArrayList(*Node).init(allocator),
            .parent = null,
            .allocator = allocator,
            .error_reporter = error_reporter,
            .data = .{ .Text = text_copy },
        };
        debugPrint("Successfully created Text node at {*}\n", .{node});
        return node;
    }

    pub fn appendChild(self: *Node, child: *Node) !void {
        debugPrint("Appending child node {*} to parent {*}\n", .{ child, self });

        if (self.node_type == .Text) {
            try self.error_reporter.report(BrowserError.InvalidParentNode, "Text nodes cannot have children", null, null);
            return BrowserError.InvalidParentNode;
        }

        try self.children.append(child);
        child.parent = self;
        debugPrint("Successfully appended child. Parent now has {d} children\n", .{self.children.items.len});
    }

    pub fn deinit(self: *Node) void {
        debugPrint("Starting deinit of node {*}\n", .{self});

        // First recursively deinit all children
        for (self.children.items) |child| {
            debugPrint("Deiniting child node {*} of parent {*}\n", .{ child, self });
            child.deinit();
            debugPrint("Destroying child node {*}\n", .{child});
            self.allocator.destroy(child);
        }
        debugPrint("Deiniting children ArrayList of node {*}\n", .{self});
        self.children.deinit();

        // Then free type-specific data
        switch (self.data) {
            .Element => |*element| {
                debugPrint("Freeing tag_name '{s}' at {*}\n", .{ element.tag_name, element.tag_name.ptr });
                self.allocator.free(element.tag_name);

                var attr_it = element.attributes.iterator();
                while (attr_it.next()) |entry| {
                    debugPrint("Freeing attribute '{s}={s}'\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                    self.allocator.free(entry.key_ptr.*);
                    self.allocator.free(entry.value_ptr.*);
                }
                debugPrint("Deiniting attributes HashMap of node {*}\n", .{self});
                element.attributes.deinit();
            },
            .Text => |text| {
                debugPrint("Freeing text content '{s}' at {*}\n", .{ text, text.ptr });
                self.allocator.free(text);
            },
            .Comment => |comment| {
                debugPrint("Freeing comment content '{s}' at {*}\n", .{ comment, comment.ptr });
                self.allocator.free(comment);
            },
            .Document => {
                debugPrint("No content to free for Document node {*}\n", .{self});
            },
        }
        debugPrint("Finished deinit of node {*}\n", .{self});
    }

    pub fn getAttribute(self: *const Node, name: []const u8) ?[]const u8 {
        return switch (self.data) {
            .Element => |element| element.attributes.get(name),
            else => null,
        };
    }

    pub fn setAttribute(self: *Node, name: []const u8, value: []const u8) !void {
        switch (self.data) {
            .Element => |*element| {
                const name_copy = try self.allocator.dupe(u8, name);
                errdefer self.allocator.free(name_copy);

                const value_copy = try self.allocator.dupe(u8, value);
                errdefer self.allocator.free(value_copy);

                // Free old value if it exists
                if (element.attributes.get(name_copy)) |old_value| {
                    const old_key = element.attributes.getKey(name_copy) orelse unreachable;
                    self.allocator.free(old_key);
                    self.allocator.free(old_value);
                }

                try element.attributes.put(name_copy, value_copy);
            },
            else => {
                try self.error_reporter.report(BrowserError.InvalidNodeType, "Cannot set attributes on non-element nodes", null, null);
                return BrowserError.InvalidNodeType;
            },
        }
    }
};
