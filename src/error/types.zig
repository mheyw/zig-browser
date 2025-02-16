const std = @import("std");

pub const BrowserError = error{
    // DOM errors
    InvalidNodeType,
    NodeNotFound,
    InvalidParentNode,

    // Parser errors
    ParseError,
    UnexpectedToken,
    UnexpectedEndOfInput,
    MalformedInput,
    MalformedTag,
    MismatchedTags,
    InvalidCharacter,

    // General errors
    OutOfMemory,
    IoError,
    Unknown,
};
