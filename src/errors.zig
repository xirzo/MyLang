pub const EvaluationError = error{
    UndefinedVariable,
    UndefinedFunction,
    DivisionByZero,
    NoSpaceLeft,
    InvalidMultiplication,
    TypeMismatch,
    InvalidFactorial,
    UnsupportedOperator,
    OutOfMemory,
    VariableNotFound,
    NoLeftExpression,
    NoRightExpression,
    WriteFailed,
    InvalidIndex,
    IndexOutOfBounds,
    UndefinedProperty,
    WrongArgumentCount,
};

pub const ExecutionError = EvaluationError || error{};

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEOF,
    MissingClosingBrace,
    MissingOpeningBrace,
    MissingClosingParenthesis,
    MissingOpeningParenthesis,
    MissingParameter,
    MissingComma,

    InvalidPrefixOperator,
    InvalidInfixOperator,
    InvalidPostfixOperator,
    BadExpressionLexeme,

    ExpectedIdentifier,
    ExpectedAssignment,
    ExpectedSemicolon,
    ExpectedRParen,
    ExpectedCommaOrRParen,

    OutOfMemory,
    ParseError,
};
