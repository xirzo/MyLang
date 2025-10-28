const std = @import("std");

pub const Lexeme = union(enum) {
    illegal: void,
    ident: []const u8,
    string: []const u8,
    assign: u8,
    number: f64,
    semicolon: u8,
    plus: u8,
    asterisk: u8,
    minus: u8,
    slash: u8,
    lparen: u8,
    rparen: u8,
    lbrace: u8,
    rbrace: u8,
    sq_rbracket: u8,
    sq_lbracket: u8,
    bang: u8,
    comma: u8,
    dot: u8,
    colon: u8,
    let: void,
    function: void,
    ret: void,
    eq: void,
    noteq: void,
    greater: void,
    greatereq: void,
    less: void,
    lesseq: void,
    true_literal: void,
    false_literal: void,
    if_cond: void,
    for_loop: void,
    while_loop: void,
    eol: void,
    eof: void,

    pub fn getOperatorChar(lex: *const Lexeme) ?u8 {
        return switch (lex.*) {
            .plus => |char| char,
            .asterisk => |char| char,
            .minus => |char| char,
            .slash => |char| char,
            .bang => |char| char,
            .sq_lbracket => |char| char,
            .dot => |char| char,
            else => null,
        };
    }

    pub fn getComparisonOp(lex: *const Lexeme) ?[]const u8 {
        return switch (lex.*) {
            .eq => "==",
            .noteq => "!=",
            .greater => ">",
            .greatereq => ">=",
            .less => "<",
            .lesseq => "<=",
            else => null,
        };
    }
};

const LexerState = struct {
    cur_pos: usize,
    read_pos: usize,
    cur_char: u8,
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

        l.readChar();
        return l;
    }

    fn saveState(l: *const Lexer) LexerState {
        return LexerState{
            .cur_pos = l.cur_pos,
            .read_pos = l.read_pos,
            .cur_char = l.cur_char,
        };
    }

    fn restoreState(l: *Lexer, state: LexerState) void {
        l.cur_pos = state.cur_pos;
        l.read_pos = state.read_pos;
        l.cur_char = state.cur_char;
    }

    fn readChar(l: *Lexer) void {
        if (l.read_pos >= l.src.len) {
            l.cur_char = 0;
        } else {
            l.cur_char = l.src[l.read_pos];
        }

        l.cur_pos = l.read_pos;
        l.read_pos += 1;
    }

    fn peekChar(l: *Lexer) u8 {
        if (l.read_pos >= l.src.len) {
            return 0;
        } else {
            return l.src[l.read_pos];
        }
    }

    fn skipWhitespaces(l: *Lexer) void {
        while (l.cur_char == ' ' or
            l.cur_char == '\t' or
            l.cur_char == '\r' or
            l.cur_char == 170)
        {
            l.readChar();
        }
    }

    fn isLetter(ch: u8) bool {
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch == '_');
    }

    fn isDigit(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }

    fn isKeyword(ident: []const u8) ?Lexeme {
        if (std.mem.eql(u8, ident, "let")) {
            return Lexeme{ .let = {} };
        }
        if (std.mem.eql(u8, ident, "fn")) {
            return Lexeme{ .function = {} };
        }
        if (std.mem.eql(u8, ident, "ret")) {
            return Lexeme{ .ret = {} };
        }
        if (std.mem.eql(u8, ident, "true")) {
            return Lexeme{ .true_literal = {} };
        }
        if (std.mem.eql(u8, ident, "false")) {
            return Lexeme{ .false_literal = {} };
        }
        if (std.mem.eql(u8, ident, "if")) {
            return Lexeme{ .if_cond = {} };
        }
        if (std.mem.eql(u8, ident, "for")) {
            return Lexeme{ .for_loop = {} };
        }
        if (std.mem.eql(u8, ident, "while")) {
            return Lexeme{ .while_loop = {} };
        }
        return null;
    }

    fn parseIdentifier(l: *Lexer) []const u8 {
        const start_pos = l.cur_pos;

        while (isLetter(l.cur_char)) {
            l.readChar();
        }

        return l.src[start_pos..l.cur_pos];
    }

    fn parseNumber(l: *Lexer) []const u8 {
        const start_pos = l.cur_pos;
        var has_dot = false;

        while (isDigit(l.cur_char) or (l.cur_char == '.' and !has_dot)) {
            if (l.cur_char == '.') {
                has_dot = true;
            }

            l.readChar();
        }

        return l.src[start_pos..l.cur_pos];
    }

    fn parseString(l: *Lexer) []const u8 {
        l.readChar();
        const start_pos = l.cur_pos;

        while (l.cur_char != '"') {
            l.readChar();
        }

        return l.src[start_pos..l.cur_pos];
    }

    pub fn next(l: *Lexer) Lexeme {
        l.skipWhitespaces();

        const lexeme = switch (l.cur_char) {
            '+' => Lexeme{ .plus = l.cur_char },
            '-' => Lexeme{ .minus = l.cur_char },
            ';' => Lexeme{ .semicolon = l.cur_char },
            '*' => Lexeme{ .asterisk = l.cur_char },
            '/' => Lexeme{ .slash = l.cur_char },
            '(' => Lexeme{ .lparen = l.cur_char },
            ')' => Lexeme{ .rparen = l.cur_char },
            '{' => Lexeme{ .lbrace = l.cur_char },
            '}' => Lexeme{ .rbrace = l.cur_char },
            '[' => Lexeme{ .sq_lbracket = l.cur_char },
            ']' => Lexeme{ .sq_rbracket = l.cur_char },
            ',' => Lexeme{ .comma = l.cur_char },
            '.' => Lexeme{ .dot = l.cur_char },
            ':' => Lexeme{ .colon = l.cur_char },
            '\n' => Lexeme{ .eol = {} },
            '"' => Lexeme{ .string = l.parseString() },
            '!' => blk: {
                if (l.peekChar() == '=') {
                    l.readChar();
                    break :blk Lexeme{ .noteq = {} };
                }
                break :blk Lexeme{ .bang = l.cur_char };
            },
            '>' => blk: {
                if (l.peekChar() == '=') {
                    l.readChar();
                    break :blk Lexeme{ .greatereq = {} };
                }
                break :blk Lexeme{ .greater = {} };
            },
            '<' => blk: {
                if (l.peekChar() == '=') {
                    l.readChar();
                    break :blk Lexeme{ .lesseq = {} };
                }
                break :blk Lexeme{ .less = {} };
            },
            '=' => blk: {
                if (l.peekChar() == '=') {
                    l.readChar();
                    break :blk Lexeme{ .eq = {} };
                }
                break :blk Lexeme{ .assign = l.cur_char };
            },
            0 => Lexeme{ .eof = {} },
            else => blk: {
                if (isLetter(l.cur_char)) {
                    const ident = l.parseIdentifier();

                    if (isKeyword(ident)) |keyword| {
                        return keyword;
                    }

                    const lexeme = Lexeme{ .ident = ident };
                    return lexeme;
                } else if (isDigit(l.cur_char)) {
                    const num_str = l.parseNumber();
                    const num = std.fmt.parseFloat(f64, num_str) catch 0;
                    const lexeme = Lexeme{ .number = num };
                    return lexeme;
                } else {
                    // std.log.err("illegal character: '{c}' (byte value: {d})", .{ l.cur_char, l.cur_char });
                    break :blk Lexeme{ .illegal = {} };
                }
            },
        };

        l.readChar();
        return lexeme;
    }

    pub fn peek(l: *Lexer) Lexeme {
        const saved_state = l.saveState();
        const token = l.next();
        l.restoreState(saved_state);
        return token;
    }

    pub fn peekNext(l: *Lexer) Lexeme {
        const saved_state = l.saveState();
        _ = l.next();
        const next_token = l.next();
        l.restoreState(saved_state);
        return next_token;
    }

    pub fn peekAhead(l: *Lexer, offset: usize) Lexeme {
        const saved_state = l.saveState();
        var i: usize = 0;
        var token = Lexeme{ .eof = {} };

        while (i <= offset) {
            token = l.next();
            if (token == .eof) break;
            i += 1;
        }

        l.restoreState(saved_state);
        return token;
    }

    pub fn checkToken(l: *Lexer, expected: std.meta.Tag(Lexeme)) bool {
        const token = l.peek();
        return @as(std.meta.Tag(Lexeme), token) == expected;
    }

    pub fn checkNextToken(l: *Lexer, expected: std.meta.Tag(Lexeme)) bool {
        const token = l.peekNext();
        return @as(std.meta.Tag(Lexeme), token) == expected;
    }
};
