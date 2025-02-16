const std = @import("std");
const browser = @import("browser");
const BrowserEngine = browser.engine.BrowserEngine;
const errors = browser.errors;

pub fn main() !void {
    // Initialize allocator with leak detection
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            std.debug.print("Warning: memory leaks detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    // Initialize error reporter
    var error_reporter = errors.ErrorReporter.init(allocator);
    defer error_reporter.deinit();

    // Initialize browser engine
    const engine = try BrowserEngine.init(allocator, &error_reporter);
    defer engine.deinit();

    // Sample HTML to parse
    const html =
        \\<html>
        \\  <body>
        \\    <h1>Hello World</h1>
        \\    <div class="content">
        \\      <p>This is a paragraph</p>
        \\      <!-- This is a comment -->
        \\      <p>Another paragraph</p>
        \\    </div>
        \\  </body>
        \\</html>
    ;

    // Load and parse the document
    engine.loadDocument(html) catch |err| {
        // If parsing fails, check for error messages
        if (error_reporter.hasErrors()) {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("\nParsing errors:\n", .{});
            for (error_reporter.errors.items) |err_msg| {
                try stderr.print("Error: {s}\n", .{err_msg.message});
            }
        }
        return err;
    };

    // Print the DOM tree
    try engine.printDOM();
}
