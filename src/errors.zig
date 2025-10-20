pub const EvaluationError = error{
    UndefinedVariable,
    UndefinedFunction,
    DivisionByZero,
    UnsupportedOperator,
    OutOfMemory,
    VariableNotFound,
};

pub const ExecutionError = EvaluationError;
