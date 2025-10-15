const std = @import("std");

pub const Lexeme = union(enum) {
    illegal: void,
    ident: []const u8,
    assign: u8,
    number: f64,
    semicolon: u8,
    plus: u8,
    asterisk: u8,
    minus: u8,
    slash: u8,
    lparen: u8,
    rparen: u8,
    bang: u8,
    eof: void,

    pub fn get_oper_char(lex: *const Lexeme) ?u8 {
        return switch (lex.*) {
            .plus => |char| char,
            .asterisk => |char| char,
            .minus => |char| char,
            .slash => |char| char,
            .bang => |char| char,
            else => null,
        };
    }
};

pub const Lexer = struct {
    src: []const u8,
    cur_pos: usize,
    read_pos: usize,
    cur_char: u8,

    pub fn init(src: []const u8) Lexer {
        var l = Lexer{
            .src = src,
            .cur_pos = 0,
            .read_pos = 0,
            .cur_char = 0,
        };
        l.read_char();
        return l;
    }

    fn read_char(l: *Lexer) void {
        if (l.read_pos >= l.src.len) {
            l.cur_char = 0;
        } else {
            l.cur_char = l.src[l.read_pos];
        }

        l.cur_pos = l.read_pos;
        l.read_pos += 1;
    }

    fn peek_char(l: *Lexer) u8 {
        if (l.read_pos >= l.src.len) {
            return 0;
        } else {
            return l.src[l.read_pos];
        }
    }

    fn skip_whitespaces(l: *Lexer) void {
        while (l.cur_char == ' ' or l.cur_char == '\t' or l.cur_char == '\n' or l.cur_char == '\r') {
            l.read_char();
        }
    }

    fn is_letter(ch: u8) bool {
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch == '_');
    }

    fn is_digit(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }

    fn parse_ident(l: *Lexer) []const u8 {
        const start_pos = l.cur_pos;

        while (Lexer.is_letter(l.cur_char)) {
            l.read_char();
        }

        return l.src[start_pos..l.cur_pos];
    }

    fn parse_number(l: *Lexer) []const u8 {
        const start_pos = l.cur_pos;

        while (Lexer.is_digit(l.cur_char)) {
            l.read_char();
        }

        return l.src[start_pos..l.cur_pos];
    }

    pub fn next(l: *Lexer) Lexeme {
        l.skip_whitespaces();

        const lexeme = switch (l.cur_char) {
            '+' => Lexeme{ .plus = l.cur_char },
            '-' => Lexeme{ .minus = l.cur_char },
            '=' => Lexeme{ .assign = l.cur_char },
            ';' => Lexeme{ .semicolon = l.cur_char },
            '*' => Lexeme{ .asterisk = l.cur_char },
            '/' => Lexeme{ .slash = l.cur_char },
            '(' => Lexeme{ .lparen = l.cur_char },
            ')' => Lexeme{ .rparen = l.cur_char },
            '!' => Lexeme{ .bang = l.cur_char },
            0 => Lexeme{ .eof = {} },
            else => blk: {
                if (Lexer.is_letter(l.cur_char)) {
                    const ident = l.parse_ident();
                    const lexeme = Lexeme{ .ident = ident };
                    return lexeme;
                } else if (Lexer.is_digit(l.cur_char)) {
                    const num_str = l.parse_number();
                    const num = std.fmt.parseFloat(f64, num_str) catch 0;
                    const lexeme = Lexeme{ .number = num };
                    return lexeme;
                } else {
                    break :blk Lexeme{ .illegal = {} };
                }
            },
        };

        l.read_char();
        return lexeme;
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
