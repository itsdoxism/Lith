# Semantic diagnostics

Lith now rejects a first set of semantic errors before handing LLVM IR to Clang. Diagnostics keep the first compiler error, include the source line, and mark the token with a caret.

Example:

```text
error: line 2: type mismatch: expected int, got str
    int count = 'hello'
                ^~~~~~~
```

The current checker covers:

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

Run the regression fixtures with:

```sh
make semantic-check
```

This is the first semantic layer, not the final type system. Later work can add richer operator typing, multiple-error recovery, source ranges spanning full expressions, array bounds policies, and module-aware name resolution.
