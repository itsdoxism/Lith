# Lith language notes

Lith is designed around a zero-shift typing philosophy. The language is still evolving, but the self-hosted LLVM compiler now covers the public reference surface plus arrays, structs, memory helpers, match expressions, interpolation, and array iteration.

## Lexical rules

- Comments begin with `#` and continue to end of line.
- Strings use single quotes.
- Blocks and structural groups use `[` and `]`.
- Identifiers use letters, digits, and `_`, but may not begin with a digit.

Source files conventionally use the `.lith` extension.

## Values and declarations

```lith
int age = 25
float ratio = 1.5
str name = 'lith'
bool ready = true
arr values = [1, 2, 3]
```

Pointers use an explicit element type:

```lith
ptr Token tokens = sys.alloc 8
```

## Functions

```lith
fn add_two [int a, int b] int [
    = a add b
]
```

Calls do not use parentheses:

```lith
int result = add_two 10, 20
```

For the bootstrap grammar, call arguments bind tighter than textual binary operators. A temporary variable is useful when a complex expression would otherwise be ambiguous.

## Textual operators

Arithmetic: `add`, `sub`, `mul`, `div`, `mod`.

Comparison: `eq`, `ne`, `gt`, `lt`, `ge`, `le`.

Logical: `and`, `or`, `not`.

## Conditionals

```lith
if [count gt 0] [
    io.print 'non-empty'
]
else [
    io.print 'empty'
]
```

## Match

```lith
fn classify [int kind] str [
    = match kind [
        is 1 [ 'word' ]
        is 2 [ 'number' ]
        else [ 'unknown' ]
    ]
]
```

## Arrays

```lith
arr values = [10, 20, 30]
values[1] = 25

int first = values[0]
```

Array element type is inferred from the literal. The self-hosted compiler supports indexing, assignment, and array iteration for the current parity surface.

## Loops

```lith
int i = 0
while [i lt 10] [
    i = i add 1
]

loop item in values [
    io.print 'item: [item]'
]
```

`break` and `continue` are supported in the current loop forms.

## Structs

```lith
struct Token [
    int kind
    str text
    int line
]

ptr Token tokens = sys.alloc 2
tokens[0].kind = 1
```

## Runtime surface

The current compiler/runtime surface includes:

- `io.read_text path`
- `io.write_text path, text`
- `io.print value`
- `str.len value`
- `str.at value, index`
- `str.slice value, start, end`
- `str.concat a, b`
- `str.eq a, b`
- `str.starts value, prefix`
- `str.trim value`
- `str.chr code`
- `int.str value`
- `sys.alloc count`
- `sys.realloc ptr, count`
- `sys.free ptr`

## Self-hosting

The current compiler source lives in ordered modules under `compiler/src/*.lith`. The build concatenates those modules into the compiler source, bootstraps Stage 1 with the trusted Python LLVM backend, then later generations are compiled by Lith itself.

The historical bootstrap implementation and runtime still contain internal `luna`/`lunac` names from the project's previous name. Those are compatibility implementation details, not the public language name.
