const std = @import("std");
const dom = @import("../dom/node.zig");
const errors = @import("../errors.zig");

pub const ParseError = errors.BrowserError;

fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub const Parser = struct {
    input: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,
    error_reporter: *errors.ErrorReporter,

    pub fn init(input: []const u8, allocator: std.mem.Allocator, error_reporter: *errors.ErrorReporter) Parser {
        debugPrint("Initializing parser with input length: {d}\n", .{input.len});
        return Parser{
            .input = input,
            .pos = 0,
            .allocator = allocator,
            .error_reporter = error_reporter,
        };
    }

    fn nextChar(self: *Parser) ?u8 {
        if (self.pos >= self.input.len) return null;
        const char = self.input[self.pos];
        self.pos += 1;
        debugPrint("nextChar: '{c}' (0x{X:0>2}) at pos {d}\n", .{ char, char, self.pos - 1 });
        return char;
    }

    fn peekChar(self: *Parser) ?u8 {
        if (self.pos >= self.input.len) return null;
        const char = self.input[self.pos];
        debugPrint("peekChar: '{c}' (0x{X:0>2}) at pos {d}\n", .{ char, char, self.pos });
        return char;
    }

    fn consumeWhile(self: *Parser, predicate: fn (u8) bool) []const u8 {
        const start = self.pos;
        while (self.peekChar()) |c| {
            if (!predicate(c)) break;
            _ = self.nextChar();
        }
        const result = self.input[start..self.pos];
        debugPrint("consumeWhile: consumed '{s}' from pos {d} to {d}\n", .{ result, start, self.pos });
        return result;
    }

    fn consumeWhitespace(self: *Parser) void {
        const start_pos = self.pos;
        _ = self.consumeWhile(std.ascii.isWhitespace);
        debugPrint("consumeWhitespace: skipped from pos {d} to {d}\n", .{ start_pos, self.pos });
    }

    fn parseTagName(self: *Parser) []const u8 {
        debugPrint("Starting parseTagName at pos {d}\n", .{self.pos});
        const name = self.consumeWhile(std.ascii.isAlphanumeric);
        debugPrint("Parsed tag name: '{s}'\n", .{name});
        return name;
    }

    fn parseText(self: *Parser) ParseError!*dom.Node {
        debugPrint("\nparseText starting at pos {d}\n", .{self.pos});
        const text = self.consumeWhile(struct {
            fn pred(c: u8) bool {
                return c != '<';
            }
        }.pred);

        if (text.len == 0) {
            debugPrint("Warning: Empty text node at pos {d}\n", .{self.pos});
        }

        const node = try dom.Node.createText(self.allocator, self.error_reporter, text);
        debugPrint("Created text node with content: '{s}'\n", .{text});
        return node;
    }

    pub fn parseNode(self: *Parser) ParseError!?*dom.Node {
        debugPrint("\nparseNode starting at pos {d}\n", .{self.pos});
        try self.consumeComment();

        if (self.peekChar()) |c| {
            if (c == '<') {
                // Handle potential malformed tags
                if (self.pos + 1 < self.input.len) {
                    const next = self.input[self.pos + 1];
                    if (next == '!') {
                        // Handle incorrectly-opened-comment error
                        debugPrint("Found potential comment-like sequence at pos {d}\n", .{self.pos});
                        try self.consumeComment();
                        return self.parseNode();
                    } else if (next == '?') {
                        // Handle unexpected-question-mark-instead-of-tag-name error
                        debugPrint("Found ? after < at pos {d}, treating as comment\n", .{self.pos});
                        try self.skipUntil('>');
                        return self.parseNode();
                    }
                }

                const node = self.parseElement() catch |err| {
                    debugPrint("Error in parseElement: {any}\n", .{err});
                    // Try to recover by skipping to next '>'
                    try self.skipUntil('>');
                    _ = self.nextChar(); // consume '>'
                    return self.parseNode();
                };
                return node;
            } else {
                return try self.parseText();
            }
        }
        return null;
    }

    fn skipUntil(self: *Parser, char: u8) !void {
        const start = self.pos;
        while (self.peekChar()) |c| {
            if (c == char) break;
            _ = self.nextChar();
        }
        debugPrint("Skipped from pos {d} to {d} looking for '{c}'\n", .{ start, self.pos, char });
    }

    fn parseElement(self: *Parser) ParseError!*dom.Node {
        const start_pos = self.pos;
        debugPrint("\nparseElement starting at pos {d}\n", .{start_pos});

        _ = self.nextChar(); // consume '<'
        const tag_name = self.parseTagName();

        if (tag_name.len == 0) {
            const ctx = if (self.pos < self.input.len)
                self.input[self.pos..@min(self.pos + 10, self.input.len)]
            else
                "";
            debugPrint("Empty tag name at pos {d}, context: '{s}'\n", .{ self.pos, ctx });
            try self.error_reporter.report(errors.BrowserError.ParseError, "Empty tag name", null, null);
            return ParseError.MalformedTag;
        }

        self.consumeWhitespace();

        // Handle attribute parsing
        while (self.peekChar()) |c| {
            if (c == '>' or c == '/') break;
            if (c == '=') {
                // Handle unexpected-equals-sign-before-attribute-name error
                debugPrint("Unexpected = before attribute name at pos {d}\n", .{self.pos});
                _ = self.nextChar();
                continue;
            }

            // TODO: Implement full attribute parsing
            _ = self.nextChar();
        }

        // Handle self-closing tags and unexpected solidus
        if (self.peekChar() == '/') {
            debugPrint("Found / in tag at pos {d}\n", .{self.pos});
            _ = self.nextChar();
            // Treat as whitespace per spec for unexpected-solidus-in-tag
        }

        const next = self.nextChar() orelse {
            debugPrint("Unexpected EOF while parsing element '{s}'\n", .{tag_name});
            return ParseError.UnexpectedEndOfInput;
        };

        if (next != '>') {
            const ctx = if (self.pos < self.input.len)
                self.input[self.pos - 1 .. @min(self.pos + 10, self.input.len)]
            else
                "";
            debugPrint("Expected '>' but got '{c}' at pos {d}, context: '{s}'\n", .{ next, self.pos - 1, ctx });
            try self.error_reporter.report(errors.BrowserError.ParseError, "Expected '>' at end of opening tag", null, null);
            // Continue parsing despite error
        }

        var element = try dom.Node.createElement(self.allocator, self.error_reporter, tag_name);
        errdefer element.deinit();

        debugPrint("Created element '{s}'\n", .{tag_name});

        // Parse children
        while (true) {
            self.consumeWhitespace();

            if (self.pos + 2 >= self.input.len) break;

            if (std.mem.eql(u8, self.input[self.pos .. self.pos + 2], "</")) {
                debugPrint("Found closing tag at pos {d}\n", .{self.pos});
                self.pos += 2;
                const end_tag_name = self.parseTagName();

                if (!std.mem.eql(u8, end_tag_name, tag_name)) {
                    debugPrint("Mismatched closing tag: expected '{s}', got '{s}'\n", .{ tag_name, end_tag_name });
                    // Record error but continue parsing
                    try self.error_reporter.report(errors.BrowserError.ParseError, "Mismatched closing tag", null, null);
                }

                self.consumeWhitespace();
                const close = self.nextChar();
                if (close != '>') {
                    debugPrint("Expected '>' at end of closing tag, got '{c}'\n", .{close orelse '?'});
                    try self.error_reporter.report(errors.BrowserError.ParseError, "Expected '>' at end of closing tag", null, null);
                    // Continue parsing despite error
                }
                break;
            }

            const child = try self.parseNode() orelse break;
            try element.appendChild(child);
        }

        debugPrint("Finished parsing element '{s}' (pos {d} to {d})\n", .{ tag_name, start_pos, self.pos });
        return element;
    }

    fn consumeComment(self: *Parser) ParseError!void {
        if (self.pos + 4 >= self.input.len) return;

        const start_pos = self.pos;
        // Handle both normal comments and incorrectly opened ones
        if (std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "<!--")) {
            debugPrint("Found comment start at pos {d}\n", .{self.pos});
            self.pos += 4;

            var found_end = false;
            while (self.pos + 3 <= self.input.len) {
                if (std.mem.eql(u8, self.input[self.pos .. self.pos + 3], "-->")) {
                    self.pos += 3;
                    found_end = true;
                    break;
                } else if (std.mem.eql(u8, self.input[self.pos .. self.pos + 3], "--!")) {
                    // Handle incorrectly-closed-comment error
                    debugPrint("Found incorrect comment end '--!' at pos {d}\n", .{self.pos});
                    self.pos += 3;
                    found_end = true;
                    break;
                }
                self.pos += 1;
            }

            if (!found_end) {
                debugPrint("Unterminated comment starting at pos {d}\n", .{start_pos});
                try self.error_reporter.report(errors.BrowserError.ParseError, "Unterminated comment", null, null);
            }
        } else if (self.pos + 2 <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + 2], "<!"))
        {
            // Handle incorrectly-opened-comment
            debugPrint("Found incorrect comment opening '<!' at pos {d}\n", .{self.pos});
            try self.skipUntil('>');
            _ = self.nextChar(); // consume '>'
        }
    }

    pub fn parseHTML(self: *Parser) ParseError!*dom.Node {
        debugPrint("Starting HTML parsing\n", .{});

        // First try to find an html root element
        if (try self.peekNextElement()) |first_tag| {
            debugPrint("Found first element tag: {s}\n", .{first_tag});

            if (std.mem.eql(u8, first_tag, "html")) {
                // Use the existing html element as root
                return try self.parseNode() orelse {
                    try self.error_reporter.report(errors.BrowserError.ParseError, "Empty document", null, null);
                    return ParseError.MalformedTag;
                };
            }
        }

        // If no html element found or it's not the first element, create an implicit root
        debugPrint("Creating implicit html root\n", .{});
        var document = try dom.Node.createElement(self.allocator, self.error_reporter, "html");
        errdefer {
            document.deinit();
            self.allocator.destroy(document);
        }

        // Parse all content as children of the implicit root
        while (true) {
            const child = try self.parseNode() orelse break;
            try document.appendChild(child);
        }

        debugPrint("Finished HTML parsing\n", .{});
        return document;
    }

    // Helper to look ahead and find the first element tag name without consuming input
    fn peekNextElement(self: *Parser) !?[]const u8 {
        var pos = self.pos;

        // Skip any whitespace and comments
        while (pos < self.input.len) {
            if (std.ascii.isWhitespace(self.input[pos])) {
                pos += 1;
                continue;
            }

            // Check for comment
            if (pos + 4 <= self.input.len and std.mem.eql(u8, self.input[pos .. pos + 4], "<!--")) {
                pos += 4;
                while (pos + 3 <= self.input.len) {
                    if (std.mem.eql(u8, self.input[pos .. pos + 3], "-->")) {
                        pos += 3;
                        break;
                    }
                    pos += 1;
                }
                continue;
            }

            break;
        }

        // Look for opening tag
        if (pos + 1 >= self.input.len or self.input[pos] != '<') return null;
        pos += 1;

        // Find tag name
        const start = pos;
        while (pos < self.input.len and std.ascii.isAlphanumeric(self.input[pos])) {
            pos += 1;
        }

        if (pos > start) {
            return self.input[start..pos];
        }

        return null;
    }
};
