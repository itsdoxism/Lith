# Luna language notes

Luna is designed around a zero-shift typing philosophy. The current compiler is intentionally small, so this document describes the implemented core rather than promising unsupported syntax.

## Lexical rules

- Comments begin with `#` and continue to end of line.
- Strings use single quotes only. Double-quoted strings are rejected.
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

## Textual operators

Arithmetic: `add`, `sub`, `mul`, `div`.

Comparison: `eq`, `ne`, `gt`, `lt`, `ge`, `le`.

Logical: `and`, `or`, `not`.

## Match-style value expressions

```luna
fn classify [int kind] str [
    = match kind [
        is 1 [ 'word' ]
        is 2 [ 'number' ]
        else [ 'unknown' ]
    ]
]
```

`if` and `match` currently share the same match-style expression parser when used as a returned value.

## Loops

```luna
while [i lt 10] [
    i = i add 1
]

loop item in values [
    io.print 'item: [item]'
]
```

## Built-in lowering

The Stage-0 compiler recognizes a tiny built-in surface during C generation:

- `io.print ...`
- `sys.alloc count`
- `sys.realloc ptr, count`
- `sys.free ptr`

These are compiler intrinsics for now, not a stable standard-library ABI.

## Self-hosting rule

A feature should not be considered self-hosting-ready until it is covered by an executable compiler test and can be represented in Luna source without relying on an untracked bootstrap-only behavior.