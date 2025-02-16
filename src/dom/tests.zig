const std = @import("std");
const testing = std.testing;
const node = @import("node.zig");
const errors = @import("../errors.zig");

test "create element node" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const elem = try node.Node.createElement(allocator, &error_reporter, "div");
    defer elem.deinit();

    try testing.expectEqual(elem.node_type, .Element);
    try testing.expectEqualStrings(elem.data.Element.tag_name, "div");
    try testing.expect(!error_reporter.hasErrors());
}

test "create text node" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const text = try node.Node.createText(allocator, &error_reporter, "Hello, world!");
    defer text.deinit();

    try testing.expectEqual(text.node_type, .Text);
    try testing.expectEqualStrings(text.data.Text, "Hello, world!");
    try testing.expect(!error_reporter.hasErrors());
}

test "append child" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const parent = try node.Node.createElement(allocator, &error_reporter, "div");
    defer parent.deinit();

    const child = try node.Node.createText(allocator, &error_reporter, "Hello");

    try parent.appendChild(child);

    try testing.expectEqual(parent.children.items.len, 1);
    try testing.expectEqual(child.parent.?, parent);
    try testing.expect(!error_reporter.hasErrors());
}

test "cannot append to text node" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const text_node = try node.Node.createText(allocator, &error_reporter, "Parent");
    defer text_node.deinit();

    const child = try node.Node.createText(allocator, &error_reporter, "Child");
    defer child.deinit();

    try testing.expectError(errors.BrowserError.InvalidParentNode, text_node.appendChild(child));
    try testing.expect(error_reporter.hasErrors());
}

test "set and get attribute" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const elem = try node.Node.createElement(allocator, &error_reporter, "div");
    defer elem.deinit();

    try elem.setAttribute("class", "container");
    try testing.expectEqualStrings(elem.getAttribute("class").?, "container");
    try testing.expect(!error_reporter.hasErrors());
}

test "cannot set attribute on text node" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const text = try node.Node.createText(allocator, &error_reporter, "Hello");
    defer text.deinit();

    try testing.expectError(errors.BrowserError.InvalidNodeType, text.setAttribute("class", "container"));
    try testing.expect(error_reporter.hasErrors());
}
