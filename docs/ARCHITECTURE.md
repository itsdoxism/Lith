# Lith compiler architecture

Lith is self-hosted. The canonical compiler is written in Lith and uses a small
trusted Python LLVM bootstrap only to recover the first compiler from a clean
checkout.

## Pipeline

```text
Lith source
    -> module loader + lexer
    -> parser + type rules
    -> typed Lith IR
    -> selected backend
        -> LLVM IR (current)
    -> Clang/LLVM
    -> native executable
```

## Typed Lith IR

Function bodies are no longer emitted as LLVM while parsing. Frontend modules
append typed target-neutral operations through `compiler/src/25_ir.lith`.
Examples include:

- `stack_alloc`, `load`, `store`
- integer/float arithmetic and comparisons
- `array_addr`, `pointer_addr`, `field_addr`
- conversions and boolean normalization
- `call`, `phi`, `branch`, `cbranch`, `return`
- allocation/reallocation/free operations

Operands are opaque handles (`$v`, `$p`, `$g`, `$s`) rather than LLVM register,
parameter, global, or string-address syntax. A function is lowered only after
its body has been parsed and type-checked.

The IR currently uses a compact sequential record buffer. This is intentionally
simple enough to remain self-hostable while providing a stable seam for later
IR passes and additional backends.

## LLVM backend

All concrete LLVM instruction text, primitive target spellings, ABI lowering,
runtime symbol mapping, and LLVM operand rendering live in:

```text
compiler/src/backend/llvm/*.lith
```

Parser/type modules should not contain LLVM instructions or call backend
functions directly. `tests/backend_boundary.sh` enforces that rule.

## Backend evolution

The LLVM backend is the production backend today. A future native or WebAssembly
backend should implement the same Lith IR lowering contract rather than change
the parser or type system.

Potential future structure:

```text
compiler/src/backend/
    llvm/
    native/
    wasm/
```

This keeps backend replacement a code-generation project instead of a compiler
frontend rewrite.
