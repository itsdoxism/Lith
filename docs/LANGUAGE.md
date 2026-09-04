# Luna language notes

Luna is designed around a zero-shift typing philosophy. The language is still evolving, so this document distinguishes the broader Stage-0 surface from the smaller bootstrap subset implemented by the self-hosted compiler.

## Lexical rules

- Comments begin with `#` and continue to end of line.
- Strings use single quotes only. Double-quoted Luna string literals are rejected.
- Common escapes such as `\n`, `\r`, `\t`, `\'`, and `\\` are supported by Stage 0.
- Blocks and structural groups use `[` and `]`.
- Identifiers use letters, digits, and `_`, but may not begin with a digit.

## Values and declarations

```luna
int age = 25
float ratio = 1.5
str name = 'luna'
bool ready = true
arr values = [1, 2, 3]
```

Pointers use an explicit element type:

```luna
ptr Token tokens = sys.alloc 8
```

The self-hosted bootstrap compiler currently relies mainly on `int`, `float`, `str`, `bool`, `char`, and pointer types. Arrays, structs, and allocation helpers are still parity work for the self-hosted compiler even though Stage 0 supports them.

## Functions

```luna
fn add_two [int a, int b] int [
    = a add b
]
```

Calls do not use parentheses:

```luna
int result = add_two 10, 20
```

For the bootstrap grammar, call arguments bind tighter than textual binary operators. Use a temporary variable when a complex binary expression would otherwise be ambiguous as a call argument.

## Textual operators

Arithmetic: `add`, `sub`, `mul`, `div`, `mod`.

Comparison: `eq`, `ne`, `gt`, `lt`, `ge`, `le`.

Logical: `and`, `or`, `not`.

## Conditionals

Statement conditionals use bracketed conditions and bodies:

```luna
if [count gt 0] [
    io.print 'non-empty'
]
else [
    io.print 'empty'
]
```

Stage 0 also supports match-style returned values:

```luna
fn classify [int kind] str [
    = match kind [
        is 1 [ 'word' ]
        is 2 [ 'number' ]
        else [ 'unknown' ]
    ]
]
```

Match expressions are not yet part of the self-hosted bootstrap subset.

## Loops

```luna
while [i lt 10] [
    i = i add 1
]

loop item in values [
    io.print 'item: [item]'
]
```

`break` and `continue` are supported by the bootstrap compiler for `while` loops. The higher-level `loop item in values` form remains Stage-0-only parity work.

## Bootstrap runtime surface

The generated C uses a small runtime for operations needed by the self-hosted compiler:

- `io.read_text path`
- `io.write_text path, text`
- `str.len value`
- `str.at value, index`
- `str.slice value, start, end`
- `str.concat a, b`
- `str.eq a, b`
- `str.starts value, prefix`
- `str.trim value`
- `str.chr code`
- `int.str value`

Stage 0 additionally recognizes `io.print`, `sys.alloc`, `sys.realloc`, and `sys.free` lowering used by the broader reference example.

## Self-hosting

`compiler/lunac.luna` contains a lexer, precedence parser, statement parser, two-pass function emitter, and C backend written in Luna. `make selfhost` proves the bootstrap by producing compiler generations until Stage 2, Stage 3, and Stage 4 generated C are byte-for-byte identical.

A feature is considered self-hosted only after the Luna compiler itself can parse and emit it and the fixed-point test continues to pass. See `docs/SELF_HOSTING.md` for the bootstrap chain.
