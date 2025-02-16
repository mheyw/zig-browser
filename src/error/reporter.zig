const std = @import("std");
const BrowserError = @import("types.zig").BrowserError;

pub const ErrorReporter = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayList(ReportedError),

    pub const ReportedError = struct {
        error_type: BrowserError,
        message: []const u8,
        line: ?usize,
        column: ?usize,
    };

    pub fn init(allocator: std.mem.Allocator) ErrorReporter {
        return ErrorReporter{
            .allocator = allocator,
            .errors = std.ArrayList(ReportedError).init(allocator),
        };
    }

    pub fn deinit(self: *ErrorReporter) void {
        for (self.errors.items) |err| {
            self.allocator.free(err.message);
        }
        self.errors.deinit();
    }

    pub fn report(self: *ErrorReporter, err_type: BrowserError, message: []const u8, line: ?usize, column: ?usize) !void {
        const msg_copy = try self.allocator.dupe(u8, message);
        try self.errors.append(ReportedError{
            .error_type = err_type,
            .message = msg_copy,
            .line = line,
            .column = column,
        });
    }

    pub fn hasErrors(self: *const ErrorReporter) bool {
        return self.errors.items.len > 0;
    }
};
