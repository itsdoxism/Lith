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

## Middle-end validation and optimization

Function bodies pass through a target-neutral middle-end before any backend
lowering:

```text
parsed + typed function
        |
        v
raw Lith IR
        |
        v
IR validator
        |
        v
IR optimizer
        |
        v
IR validator
        |
        v
selected backend
```

The validator checks the internal record shape, opcode set, SSA temporary
use/definition ordering, branch targets, phi predecessors, call payloads, and
basic-block termination. A validation failure is a compiler-internal error and
prevents backend lowering.

The optimizer is intentionally conservative and target-neutral. Its current
passes include:

- integer/boolean constant propagation and folding
- simplification of constant conditional branches
- immediate store-to-load forwarding for the same local address
- dead-value elimination for pure IR operations only
- pruning of unreferenced compiler-generated `dead.*` basic blocks

Side-effecting operations (`call`, `store`, allocation, free, printing, and
control-flow terminators) are never removed by dead-value elimination. Backend-
specific peepholes remain the backend's responsibility; language semantics and
middle-end transforms must not depend on LLVM spelling.

## Indexed IR storage

Optimizer v2 keeps each function in one compact serialized arena and builds a
small integer record-start index for repeated middle-end access. This avoids
materializing per-record heap strings or rescanning the entire function for
every pass. Dead-value analysis now runs backward over the index and emits the
kept records in one forward pass.

The shared string-table helpers also avoid allocating temporary key/value
slices for every `map_get` probe; only a matched value is materialized. This is
important because symbol tables, validator state, and optimizer alias maps all
use the same compact map representation.

On the self-host compiler workload used during this migration, peak memory fell
from roughly 631 MB to about 52 MB while preserving the fixed point. The number
is environment-specific and is documented as a development measurement rather
than a language guarantee.
