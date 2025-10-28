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
};

pub const ExecutionError = EvaluationError;
