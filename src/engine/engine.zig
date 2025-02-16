const std = @import("std");
const dom = @import("../dom/node.zig");
const html = @import("../html/parser.zig");
const errors = @import("../errors.zig");

fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub const EngineError = error{
    InitializationError,
    LoadError,
    ParseError,
    RenderError,
} || errors.BrowserError;

pub const BrowserEngine = struct {
    allocator: std.mem.Allocator,
    error_reporter: *errors.ErrorReporter,
    document: ?*dom.Node,
    // Will add more components as we build them:
    // css_engine: CSSEngine,
    // renderer: Renderer,
    // network: NetworkClient,

    pub fn init(allocator: std.mem.Allocator, error_reporter: *errors.ErrorReporter) !*BrowserEngine {
        debugPrint("Initializing browser engine\n", .{});

        const engine = try allocator.create(BrowserEngine);
        engine.* = BrowserEngine{
            .allocator = allocator,
            .error_reporter = error_reporter,
            .document = null,
        };

        debugPrint("Browser engine initialized\n", .{});
        return engine;
    }

    pub fn deinit(self: *BrowserEngine) void {
        debugPrint("Starting browser engine cleanup\n", .{});

        if (self.document) |doc| {
            debugPrint("Cleaning up document\n", .{});
            doc.deinit();
            self.allocator.destroy(doc);
            self.document = null;
        }

        debugPrint("Destroying engine\n", .{});
        self.allocator.destroy(self);
    }

    pub fn loadDocument(self: *BrowserEngine, html_content: []const u8) !void {
        debugPrint("Loading document with {} bytes\n", .{html_content.len});

        // Clean up any existing document
        if (self.document) |doc| {
            debugPrint("Cleaning up existing document\n", .{});
            doc.deinit();
            self.allocator.destroy(doc);
            self.document = null;
        }

        // Parse HTML into DOM
        var parser = html.Parser.init(html_content, self.allocator, self.error_reporter);
        self.document = try parser.parseHTML();

        debugPrint("Document loaded successfully\n", .{});
    }

    pub fn printDOM(self: *BrowserEngine) !void {
        if (self.document) |doc| {
            try self.printNode(doc, 0);
        } else {
            debugPrint("No document loaded\n", .{});
        }
    }

    fn printNode(self: *BrowserEngine, node: *const dom.Node, depth: usize) !void {
        const stdout = std.io.getStdOut().writer();

        // Print indentation
        try stdout.writeByteNTimes(' ', depth * 2);

        switch (node.node_type) {
            .Element => {
                try stdout.print("<{s}>\n", .{node.data.Element.tag_name});
            },
            .Text => {
                try stdout.print("{s}\n", .{node.data.Text});
            },
            else => {},
        }

        // Print children recursively
        for (node.children.items) |child| {
            try self.printNode(child, depth + 1);
        }

        // Print closing tag for elements
        if (node.node_type == .Element) {
            try stdout.writeByteNTimes(' ', depth * 2);
            try stdout.print("</{s}>\n", .{node.data.Element.tag_name});
        }
    }
};
