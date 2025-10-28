This is a simple interpreter written in [Zig](https://ziglang.org) in order to learn it. It utilizes [Pratt parsing](https://en.wikipedia.org/wiki/Operator-precedence_parser) technique.

## Build

Clone the repository
```sh
git https://github.com/xirzo/mylang && cd mylang
```

Build the interpreter

```sh
zig build
```

Get into `bin` directory

```sh
cd ./zig-out/bin
```

Run the executable

```sh
./mylang sample.my
```

### sample.my

```
fn fib(n) {
    if n <= 1 {
        ret n;
    }

    ret fib(n-1) + fib(n-2);
}

println(fib(5));
```

## Features

- [x] structs (as objects)
- [x] if statements
- [x] built-in functions (e.g. println)
- [x] function declarations
- [x] function calls 
- [x] blocks
- [x] let statements
- [x] return statements
- [x] infix operators
- [x] prefix operators
- [x] postfix operators
- [] else statements
- [] for loops
- [] while loops

## Sources

- [Grammars, parsing, and recursive descent](https://www.youtube.com/watch?v=ENKT0Z3gldE&list=LL&index=3)
- [Simple but Powerful Pratt Parsing](https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html#Pratt-parsing-the-general-shape)
- [Zig docs](https://ziglang.org/documentation/0.14.1/)
