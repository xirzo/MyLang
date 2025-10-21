pub const Value = union(enum) {
    number: f64,
    string: []const u8,
    char: u8,
    none: void,
};
