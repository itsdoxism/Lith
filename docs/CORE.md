# Lith core language semantics

This document defines the intended stable core semantics for Lith. It deliberately excludes package management, editors, formatters, registries, and other ecosystem tooling.

## Design goals

Lith is a native, ahead-of-time compiled, zero-shift language. The core favors explicit, predictable semantics and small runtime cost over hidden allocation or a mandatory garbage collector.

## Primitive values

The core scalar types are:

- `int`: signed 32-bit integer
- `char`: 32-bit integer code value
- `float`: IEEE-754 64-bit floating point
- `bool`: one-bit logical value
- `str`: pointer-like UTF-8 runtime string handle
- `ptr T`: opaque native pointer to `T`

`null` is the null pointer literal and can convert to `str` or any `ptr T`.

Integer `add`, `sub`, and `mul` use 32-bit wrapping arithmetic. Signed integer comparisons use two's-complement signed ordering. Division and remainder by zero are invalid program behavior; a future checked mode may trap earlier, but the core does not insert a mandatory branch into every operation.

## Numeric conversion

Implicit conversion is intentionally one-way:

- `char -> int`
- `int -> char`
- `int -> float`
- `char -> float`
- scalar/pointer-like value -> `bool` in condition or boolean destination contexts

No implicit `float -> int` narrowing occurs.

Explicit conversion uses the textual postfix operator `as`:

```lith
int rounded = ratio as int
float widened = count as float
```

Explicit numeric casts support `int`, `char`, `float`, and `bool` where an LLVM conversion exists. Pointer-like casts are allowed between `str` and `ptr T`, and between pointer element types because LLVM pointers are opaque; such casts do not change the address.

Binary arithmetic promotes an integer-like operand to `float` when the other operand is `float`. Integer-like pairs produce `int`. `bool` is not a numeric operand.

## Expressions and calls

Binary precedence, from low to high:

1. `or`
2. `and`
3. equality and relational operators
4. `add`, `sub`
5. `mul`, `div`, `mod`
6. `as`

Square brackets can group an expression without shifted punctuation:

```lith
int x = [a add b] mul c
```

Function calls retain Lith's zero-parenthesis spelling:

```lith
int result = add_two 10, 20
```

Arguments after the first are comma-separated. A complex argument is grouped explicitly:

```lith
int result = add_two [a add b], [c mul d]
```

This makes call boundaries deterministic. Zero-argument calls use an empty bracket marker:

```lith
int value = next_value []
```

## Arrays

Arrays are fixed-size first-class values. Their explicit type is prefix-shaped:

```lith
arr int 3
arr Token 16
arr arr int 4 3
```

`arr T N` means an array containing `N` values of type `T`. The size is part of the type.

Local declarations can still infer type and size from a literal:

```lith
arr values = [10, 20, 30]
```

Explicit array declarations are also valid:

```lith
arr int 3 values = [10, 20, 30]
```

Arrays have value semantics: assignment, function argument passing, and function return copy the fixed-size value. Indexing produces an lvalue when the base array is addressable. Arrays can be global when initialized with compile-time literals.

Array indexing is intentionally unchecked in the default core profile. An out-of-range access is invalid program behavior. This keeps the default language suitable for low-overhead native code; checked containers can be built above the core.

## Structs

Structs are fixed-layout value types. They can be locals, fields, parameters, return values, array elements, or heap pointees.

A positional struct literal uses the type name followed by a bracketed field list in declaration order:

```lith
Token t = Token [1, 'word', 12]
```

Struct assignment and function passing copy the whole value. Member access on an addressable struct produces an addressable field; member access on a temporary is readable but is not assignable unless materialized by the compiler.

## Match

`match` is a normal expression, not a return-only special form:

```lith
str kind_name = match kind [
    is 1 [ 'word' ]
    is 2 [ 'number' ]
    else [ 'unknown' ]
]
```

All arms must produce compatible values. The first arm establishes the result type; later arms must be implicitly convertible to it. Use `as` when an explicit narrowing or reinterpretation is intended.

## Memory model

Lith has no mandatory garbage collector. Heap allocation is explicit:

```lith
ptr Token tokens = sys.alloc 16
sys.free tokens
```

`sys.alloc N` allocates storage for `N` values of the destination pointer's pointee type. `sys.realloc` resizes an existing allocation using the same element model. `sys.free` releases an allocation.

Ownership is manual. After `sys.free`, every pointer into the freed allocation is invalid. Double free, use-after-free, dereferencing `null`, and dereferencing an invalid pointer are invalid program behavior. This is a deliberate low-level contract, not an accidental omission.

## Modules

Source modules are part of the language core. Builtin capability imports keep identifier spelling:

```lith
use io
use str
```

Source imports use a string path:

```lith
use './parser.lith'
use './token.lith'
```

Source imports are resolved relative to the importing file, recursively, exactly once per canonical path. Cycles are rejected with a diagnostic. Dependencies are compiled into the same program namespace; duplicate top-level declarations remain errors.

The module resolver is a source-loading concern and does not change the generated runtime ABI.

## Core-completion bar

The core is considered complete when the canonical self-hosted compiler implements these semantics with regression coverage for:

- first-class arrays across locals/globals/parameters/returns
- numeric promotion and explicit `as` conversion
- deterministic grouped call arguments and zero-argument calls
- general `match` expressions
- struct value construction/copy/pass/return
- `null` and the documented manual memory contract
- recursive relative source imports with cycle/duplicate protection
- source-aware diagnostics for invalid variants of the above
