const LexemTag = enum {
    ident,
};

const Lexem = union(LexemTag) {
    ident,
};

pub const Lexer = struct {
    pub fn next() Lexem {}
};

