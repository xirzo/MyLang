const std = @import("std");

pub const LexemeTag = enum {
    illegal,
    ident,
    assign,
    number,
    semicolon,
    plus,
    asterisk,
    minus,
    slash,
    eof,
};

pub const Lexeme = union(LexemeTag) {
    illegal: void,
    ident: []const u8,
    assign: u8,
    number: i64,
    semicolon: u8,
    plus: u8,
    asterisk: u8,
    minus: u8,
    slash: u8,
    eof: u8,

    pub fn get_binary_oper_char(self: *const Lexeme) ?u8 {
        return switch (self.*) {
            .plus => |char| char,
            .asterisk => |char| char,
            .minus => |char| char,
            .slash => |char| char,
            else => null,
        };
    }
};

pub const Lexer = struct {
    src: []const u8,
    cur_char: u8,
    cur_pos: usize,
    read_pos: usize,

    pub fn init(src: []const u8) Lexer {
        var l = Lexer{
            .src = src,
            .cur_char = 0,
            .cur_pos = 0,
            .read_pos = 1,
        };

        if (l.src.len > 0) {
            l.cur_char = l.src[0];
        }

        return l;
    }

    fn read_char(l: *Lexer) void {
        if (l.read_pos >= l.src.len) {
            l.cur_char = 0;
            return;
        }

        l.cur_pos += 1;
        l.read_pos += 1;
        l.cur_char = l.src[l.cur_pos];
    }

    fn peek_char(l: *Lexer) u8 {
        if (l.read_pos > l.src.len) {
            return 0;
        }

        return l.src[l.read_pos];
    }

    fn skip_whitespaces(l: *Lexer) void {
        while (l.cur_pos < l.src.len and std.ascii.isWhitespace(l.cur_char)) {
            l.read_char();
        }
    }

    fn parse_ident(l: *Lexer) Lexeme {
        const start_index: usize = l.cur_pos;

        while (l.read_pos < l.src.len and
            (std.ascii.isAlphanumeric(l.src[l.read_pos]) or l.src[l.read_pos] == '_'))
        {
            l.read_char();
        }

        l.read_char();

        return Lexeme{ .ident = l.src[start_index..l.cur_pos] };
    }

    fn parse_number(l: *Lexer) Lexeme {
        const start_index: usize = l.cur_pos;

        while (l.read_pos < l.src.len and std.ascii.isDigit(l.src[l.read_pos])) {
            // std.debug.print("print number string loop: {c}\n", .{l.src[l.read_pos]});
            l.read_char();
        }

        l.read_char();

        // maybe will cause bugs, as I am not sure that it is valid to add 1 to cur_pos
        // but this page says that slices exclude last element
        // https://zig.guide/language-basics/slices/

        const num_str = switch (l.cur_pos - start_index) {
            0 => l.src[start_index .. l.cur_pos + 1],
            else => l.src[start_index..l.cur_pos],
        };

        // std.debug.print("print number string: {s}\n", .{num_str});

        const num: i64 = std.fmt.parseInt(i64, num_str, 10) catch |err| blk: {
            switch (err) {
                error.Overflow => std.log.err("parse number overflow", .{}),
                error.InvalidCharacter => std.log.err("parse number invalid character: {s}", .{num_str}),
            }
            break :blk 0;
        };

        return Lexeme{ .number = num };
    }

    pub fn next(l: *Lexer) Lexeme {
        l.skip_whitespaces();

        if (l.cur_pos >= l.src.len or l.cur_char == 0) {
            return Lexeme{ .eof = 0 };
        }

        // std.debug.print("lexer next: {c}\n", .{l.cur_char});

        return switch (l.cur_char) {
            '=' => blk: {
                const ch: u8 = l.cur_char;
                l.read_char();
                break :blk Lexeme{ .assign = ch };
            },
            ';' => blk: {
                const ch: u8 = l.cur_char;
                l.read_char();
                break :blk Lexeme{ .semicolon = ch };
            },
            '+' => blk: {
                const ch: u8 = l.cur_char;
                l.read_char();
                break :blk Lexeme{ .plus = ch };
            },
            '*' => blk: {
                const ch: u8 = l.cur_char;
                l.read_char();
                break :blk Lexeme{ .asterisk = ch };
            },
            '/' => blk: {
                const ch: u8 = l.cur_char;
                l.read_char();
                break :blk Lexeme{ .slash = ch };
            },
            '-' => blk: {
                const ch: u8 = l.cur_char;
                l.read_char();
                break :blk Lexeme{ .minus = ch };
            },
            else => blk: {
                if (std.ascii.isAlphabetic(l.cur_char)) {
                    break :blk l.parse_ident();
                }
                if (std.ascii.isDigit(l.cur_char)) {
                    break :blk l.parse_number();
                }

                l.read_char();
                break :blk Lexeme{ .illegal = {} };
            },
        };
    }

    pub fn peek(l: *Lexer) Lexeme {
        const cur_char: u8 = l.cur_char;
        const cur_pos: usize = l.cur_pos;
        const read_pos: usize = l.read_pos;

        const lex: Lexeme = l.next();

        l.cur_char = cur_char;
        l.cur_pos = cur_pos;
        l.read_pos = read_pos;

        return lex;
    }
};
