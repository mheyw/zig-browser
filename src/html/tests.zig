// src/html/tests.zig
const std = @import("std");
const testing = std.testing;
const Parser = @import("parser.zig").Parser;
const errors = @import("../errors.zig");

test "parse simple text node" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    var parser = Parser.init("Hello, world!", allocator, &error_reporter);
    const node = try parser.parseNode();
    defer node.?.deinit();

    try testing.expectEqual(node.?.node_type, .Text);
    try testing.expectEqualStrings(node.?.data.Text, "Hello, world!");
}

test "parse simple element" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    var parser = Parser.init("<div>Hello</div>", allocator, &error_reporter);
    const node = try parser.parseNode();
    defer node.?.deinit();

    try testing.expectEqual(node.?.node_type, .Element);
    try testing.expectEqualStrings(node.?.data.Element.tag_name, "div");
    try testing.expectEqual(node.?.children.items.len, 1);
    try testing.expectEqual(node.?.children.items[0].node_type, .Text);
    try testing.expectEqualStrings(node.?.children.items[0].data.Text, "Hello");
}

test "parse nested elements" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    var parser = Parser.init("<div><p>Hello</p><p>World</p></div>", allocator, &error_reporter);
    const node = try parser.parseNode();
    defer node.?.deinit();

    try testing.expectEqual(node.?.node_type, .Element);
    try testing.expectEqualStrings(node.?.data.Element.tag_name, "div");
    try testing.expectEqual(node.?.children.items.len, 2);

    // Check first p element
    const p1 = node.?.children.items[0];
    try testing.expectEqual(p1.node_type, .Element);
    try testing.expectEqualStrings(p1.data.Element.tag_name, "p");
    try testing.expectEqualStrings(p1.children.items[0].data.Text, "Hello");

    // Check second p element
    const p2 = node.?.children.items[1];
    try testing.expectEqual(p2.node_type, .Element);
    try testing.expectEqualStrings(p2.data.Element.tag_name, "p");
    try testing.expectEqualStrings(p2.children.items[0].data.Text, "World");
}

test "parse comment" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    var parser = Parser.init("<!-- Comment --><div>Content</div>", allocator, &error_reporter);
    const node = try parser.parseNode();
    defer node.?.deinit();

    try testing.expectEqual(node.?.node_type, .Element);
    try testing.expectEqualStrings(node.?.data.Element.tag_name, "div");
}

test "handle mismatched tags" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    var parser = Parser.init("<div><p>Text</div></p>", allocator, &error_reporter);
    const node = try parser.parseNode();
    defer node.?.deinit();

    // Should still parse but report an error
    try testing.expect(error_reporter.hasErrors());
}
