const std = @import("std");

pub const LexemeTag = enum {
    ident,
    assign,
    number,
    semicolon,
    eof,
};

pub const Lexeme = union(LexemeTag) {
    ident: []const u8,
    assign: u8,
    number: i64,
    semicolon: u8,
    eof: u8,
};

pub const Lexer = struct {
    src: []const u8,
    cur_pos: i64,
    read_pos: i64,

    pub fn init(src: []const u8) Lexer {
        return .{
            .src = src,
            .cur_pos = -1,
            .read_pos = 0,
        };
    }

    fn read_char(l: *Lexer) void {
        if (l.read_pos >= l.src.len) {
            return;
        }

        l.cur_pos += 1;
        l.read_pos += 1;
    }

    fn skip_whitespaces(l: *Lexer) void {
        while (std.ascii.isWhitespace(l.src[l.read_pos])) {
            l.read_char();
        }
    }

    pub fn next(l: *Lexer) Lexeme {
        l.skip_whitespaces();

        return .{
            .ident = "loool",
        };
    }
};
