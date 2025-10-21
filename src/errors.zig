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
};

pub const ExecutionError = EvaluationError;
