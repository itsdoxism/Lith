# Semantic diagnostics

Lith rejects semantic errors before handing LLVM IR to Clang. Recoverable semantic errors are collected so one compile can report several independent problems, while malformed lexer/parser input is still treated as fatal.

Example:

```text
error: line 2: type mismatch: expected int, got str
    int count = 'hello'
                ^~~~~~~

error: line 3: operator add does not support int and str
    int total = 1 add 'two'
                  ^~~
```

The checker currently covers:

- unknown variables and functions
- function argument count and argument type mismatches
- declaration, assignment, return, match-return, and array-element type mismatches
- duplicate globals, functions, parameters, locals, structs, and struct fields
- `break` / `continue` outside loops
- assignment to non-writable expressions
- non-integer array or pointer indexes
- unknown struct fields and invalid member/index access
- invalid `sys.alloc`, `sys.realloc`, and `sys.free` operand types
- explicit errors for unsupported global arrays, array parameters, array return types, and array struct fields
- binary operator type checking for arithmetic, comparisons, equality, and logical operators

Operator rules are intentionally explicit:

- `add`, `sub`, `mul`, `div`, `mod` accept integer-like pairs (`int` / `char`) or `float` + `float`
- `gt`, `lt`, `ge`, `le` accept integer-like pairs or `float` + `float`
- `eq`, `ne` support integer-like values, bools, floats, strings, and pointer-like values when both operands are compatible categories
- `and`, `or`, and condition conversion accept bool, integer-like, float, string, and pointer-like values
- mixed unsupported categories are rejected instead of producing malformed LLVM IR

Diagnostics are capped at 20 entries per compile so badly broken input cannot flood output. Invalid programs do not write LLVM IR.

Run the regression fixtures with:

```sh
make semantic-check
```

Later work can improve full-expression source ranges, richer numeric promotion rules, array bounds policies, and module-aware name resolution.
