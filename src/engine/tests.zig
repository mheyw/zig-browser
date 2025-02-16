const std = @import("std");
const testing = std.testing;
const BrowserEngine = @import("engine.zig");
const errors = @import("../errors.zig");

test "browser engine init/deinit" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const engine = try BrowserEngine.init(allocator, &error_reporter);
    defer engine.deinit();

    try testing.expect(engine.document == null);
}

test "browser engine load document" {
    const allocator = testing.allocator;
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    const engine = try BrowserEngine.init(allocator, &error_reporter);
    defer engine.deinit();

    const html_content =
        \\<html><body><h1>Test</h1></body></html>
    ;

    try engine.loadDocument(html_content);
    try testing.expect(engine.document != null);
}
