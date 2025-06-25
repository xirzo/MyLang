const std = @import("std");

pub const LexemeTag = enum {
    illegal,
    ident,
    assign,
    number,
    semicolon,
    eof,
};

pub const Lexeme = union(LexemeTag) {
    illegal: void,
    ident: []const u8,
    assign: u8,
    number: i64,
    semicolon: u8,
    eof: u8,
};

pub const Lexer = struct {
    src: []const u8,
    cur_char: u8,
    cur_pos: usize,
    read_pos: usize,

    pub fn init(src: []const u8) Lexer {
        return .{
            .src = src,
            .cur_char = undefined,
            .cur_pos = 0,
            .read_pos = 1,
        };
    }

    fn read_char(l: *Lexer) void {
        if (l.read_pos >= l.src.len) {
            l.cur_char = undefined;
            return;
        }

        l.cur_pos += 1;
        l.read_pos += 1;
        l.cur_char = l.src[l.cur_pos];
    }

    fn peek_char(l: *Lexer) u8 {
        if (l.read_pos > l.src.len) {
            return undefined;
        }

        return l.src[l.read_pos];
    }

    fn skip_whitespaces(l: *Lexer) void {
        while (std.ascii.isWhitespace(l.src[l.read_pos])) {
            l.read_char();
        }
    }

    fn parse_ident(l: *Lexer) Lexeme {
        const start_index: usize = l.cur_pos;

        while (!std.ascii.isAlphabetic(l.peek_char())) {
            l.read_char();
        }

        return Lexeme{ .ident = l.src[start_index..l.cur_pos] };
    }

    pub fn next(l: *Lexer) Lexeme {
        l.skip_whitespaces();

        return switch (l.peek_char()) {
            ';' => Lexeme{ .semicolon = l.peek_char() },

            else => {
                if (std.ascii.isAlphabetic(l.peek_char())) {
                    return l.parse_ident();
                }

                return Lexeme{ .illegal = {} };
            },
        };
    }
};
