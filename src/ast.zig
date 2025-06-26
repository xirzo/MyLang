const Lexeme = @import("lexer.zig").Lexeme;

// Expr =
//     Factor
//   | Expr '+' Factor
// Factor =
//     Atom
//   | Factor '*' Atom
// Atom =
//     'number'
//   | '(' Expr ')'

pub const Atom = struct {
    value: i64,
};

pub const Ast = union {
    atom: Atom,
};

// const BinaryExpr = struct {
//     op: Lexeme,
//     left: *Expr,
//     right: *Expr,
// };
