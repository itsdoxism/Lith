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

`null` is the null pointer literal. Its internal compiler type is universal only for null conversion: it can implicitly initialize `str` or any `ptr T`, but ordinary non-null pointer values do not silently change pointer type.

Integer `add`, `sub`, and `mul` use 32-bit wrapping arithmetic. Signed integer comparisons use two's-complement signed ordering. Division and remainder by zero are invalid program behavior; a future checked mode may trap earlier, but the core does not insert a mandatory branch into every operation.

## Numeric and pointer conversion

Implicit conversion is deliberately small and compatibility-preserving:

- `char -> int`
- `int -> char`
- `bool -> int` or `char`, normalized to `0` or `1`
- `int -> float`
- `char -> float`
- scalar or pointer-like value -> `bool` in condition or boolean-destination contexts
- `null -> str`
- `null -> ptr T`

No implicit `float -> int` narrowing occurs. A non-null `ptr A` does not implicitly become `ptr B`, and `str` does not implicitly reinterpret as an arbitrary pointer.

Explicit conversion uses the textual postfix operator `as`:

```lith
int rounded = ratio as int
float widened = count as float
ptr char raw = text as ptr char
ptr Header header = bytes as ptr Header
```

Explicit numeric casts support `int`, `char`, `float`, and `bool` where an LLVM conversion exists. Explicit pointer-like casts are allowed between `str` and `ptr T`, and between pointer element types because LLVM pointers are opaque; such casts do not change the address. They change only the source-language type and therefore make potentially unsafe reinterpretation visible in source code.

Binary arithmetic promotes an integer-like operand to `float` when the other operand is `float`. Integer-like pairs produce `int`. `bool` is not a numeric binary operand even though a boolean can be assigned to `int` for compatibility.

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

This makes call boundaries deterministic. Zero-argument calls require an empty bracket marker:

```lith
int value = next_value []
```

A bare zero-argument function name is not a call.

Postfix indexing and member access compose in source order. Expressions such as `bucket.items[1]`, `nodes[0].next.value`, and aggregate-returning-call postfixes are handled by one postfix chain rather than special cases.

## Arrays

Arrays are fixed-size first-class values. Their explicit type is prefix-shaped:

```lith
arr int 3
arr Token 16
arr arr int 4 3
```

`arr T N` means an array containing `N` values of type `T`. The size is part of the type. Nested arrays are recursive fixed-size values; `arr arr int 4 3` means three values whose type is `arr int 4`.

Local declarations can still infer type and size from a non-nested literal:

```lith
arr values = [10, 20, 30]
```

Nested arrays use an explicit type so both dimensions are unambiguous:

```lith
arr arr int 2 2 matrix = [[1, 2], [3, 4]]
```

Arrays have value semantics: assignment, function argument passing, and function return copy the fixed-size value. Indexing produces an lvalue when the base array is addressable. Arrays can be global when initialized with compile-time literals, and arrays can be struct fields.

Array indexing is intentionally unchecked in the default core profile. An out-of-range access is invalid program behavior. This keeps the default language suitable for low-overhead native code; checked containers can be built above the core.

## Structs

Structs are fixed-layout value types. They can be locals, fields, parameters, return values, array elements, or heap pointees.

A positional struct literal uses the type name followed by a bracketed field list in declaration order:

```lith
Token t = Token [1, 'word', 12]
```

Array fields accept nested literals using their declared fixed-array type:

```lith
struct Bucket [
    arr int 2 items
]

Bucket b = Bucket [[10, 20]]
```

Struct assignment and function passing copy the whole value. Aggregate temporaries returned by functions or `match` are materialized when an address is required, so postfix reads such as `make_pair [].right` and `match ... ].field` remain composable. Pointer-to-struct member access uses the same field syntax as a struct value.

Struct names are visible across the compilation unit before field layouts are finalized. Pointer recursion such as `ptr Node next` is valid. A direct or indirect by-value recursive layout is rejected because it would have infinite size.

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

Simple targets use the compact form above. A complex target is grouped so the match-body delimiter stays unambiguous:

```lith
int result = match [kind add 1] [
    is 2 [ 10 ]
    else [ 0 ]
]
```

Aggregate-valued matches are first-class and may be assigned, returned, indexed, or have members read immediately.

## Memory and string ownership

Lith has no mandatory garbage collector. Heap allocation is explicit:

```lith
ptr Token tokens = sys.alloc 16
sys.free tokens
```

`sys.alloc N` allocates storage for `N` values of the destination pointer's pointee type. `sys.realloc` resizes an existing allocation using the same element model. `sys.free` releases an allocation.

Ownership is manual. After `sys.free`, every pointer into the freed allocation is invalid. Double free, use-after-free, dereferencing `null`, and dereferencing an invalid pointer are invalid program behavior. This is a deliberate low-level contract, not an accidental omission.

`str` values are pointer-like but do not all have the same ownership source:

- string literals are static/borrowed and must not be freed;
- `io.read_text` returns heap-backed text owned by the caller;
- allocation-producing string helpers such as `str.slice`, `str.concat`, `str.trim`, `str.chr`, and `int.str` return heap-backed strings owned by the caller;
- passing or assigning a `str` copies the handle, not the underlying bytes.

The core runtime does not insert hidden reference counting. Freeing an owned string is a manual operation; freeing a borrowed/static string, freeing the same owned string twice, or using aliases after the allocation is released is invalid program behavior. Code that needs to make the low-level ownership operation visually explicit may reinterpret an owned string with `as ptr char` before release.

This model intentionally favors a tiny runtime. Safer owned-string/container abstractions can be implemented above the core without changing the ABI.

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

Source imports are resolved relative to the importing file, recursively, exactly once per canonical path. Cycles and missing files are rejected with diagnostics. Dependencies are compiled into the same program namespace; duplicate top-level declarations remain errors rather than silently shadowing one another.

Imported-source diagnostics preserve the canonical source path and local line number rather than exposing the synthetic merged-source line number. The module resolver is a source-loading concern and does not change the generated runtime ABI.

## Core-completion bar

The core is considered complete when the canonical self-hosted compiler implements these semantics with regression coverage for:

- first-class arrays across locals/globals/fields/parameters/returns, including explicit nested arrays
- numeric promotion, explicit `as` conversion, and explicit-only non-null pointer reinterpretation
- deterministic grouped call arguments and required zero-argument call markers
- general scalar and aggregate `match` expressions
- struct value construction/copy/pass/return, recursive-pointer layouts, and postfix composition
- `null` and the documented manual memory/string-ownership contract
- recursive relative source imports with cycle/missing/deduplicate protection
- source-file-aware diagnostics for invalid variants of the above
- self-hosted fixed-point compilation after the feature set is enabled
