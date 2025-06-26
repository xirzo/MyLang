const Lexeme = @import("lexer.zig").Lexeme;

pub const Atom = struct {
    value: i64,
};

pub const Op = struct {
    value: u8,
    lhs: *Ast,
    rhs: *Ast,
};

pub const Ast = union {
    atom: Atom,
    op: Op,
};
