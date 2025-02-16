const std = @import("std");
const testing = std.testing;
const Reporter = @import("reporter.zig").ErrorReporter;
const BrowserError = @import("types.zig").BrowserError;

test "error reporting" {
    var error_reporter = Reporter.init(testing.allocator);
    defer error_reporter.deinit();

    try error_reporter.report(BrowserError.ParseError, "Unexpected end of input", 1, 10);

    try testing.expect(error_reporter.hasErrors());
    try testing.expectEqual(error_reporter.errors.items.len, 1);

    const reported_error = error_reporter.errors.items[0];
    try testing.expectEqual(reported_error.error_type, BrowserError.ParseError);
    try testing.expectEqualStrings(reported_error.message, "Unexpected end of input");
    try testing.expectEqual(reported_error.line.?, 1);
    try testing.expectEqual(reported_error.column.?, 10);
}
