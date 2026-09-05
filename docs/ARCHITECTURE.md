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

The IR builder now stores function records in growable parallel field arrays
(`op`, `a`, `b`, `c`, `d`, `e`) instead of repeatedly rebuilding one giant
serialized string. A compatibility serializer currently feeds the existing
validator/optimizer boundary; later passes can migrate directly onto the
structured arena without changing frontend semantics. This removes the main
quadratic string-growth cost while preserving the target-neutral IR contract.

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

Function bodies pass through a target-neutral, verified middle-end before any
backend lowering:

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
constant/alias optimizer
        |
        v
IR validator
        |
        v
DCE/indexed cleanup
        |
        v
IR validator
        |
        v
CFG reachability + unreachable-block pruning
        |
        v
IR validator
        |
        v
selected backend
```

`ir_run_optimization_pipeline` is the central pass manager. Every transform is
verified before the next pass consumes its output, so malformed target-neutral
IR fails at the pass boundary instead of surfacing later as backend-specific
LLVM damage.

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
- indexed dead-value cleanup
- CFG reachability from the implicit `entry` block
- removal of unreachable basic blocks regardless of generated label spelling
- pruning of phi incoming edges whose predecessor blocks were removed

Side-effecting operations (`call`, `store`, allocation, free, printing, and
control-flow terminators) are never removed by dead-value elimination. Whole
blocks containing side effects may still disappear when CFG analysis proves the
block unreachable. Backend-specific peepholes remain the backend's
responsibility; language semantics and middle-end transforms must not depend on
LLVM spelling.

## CFG analysis

`compiler/src/28_ir_cfg.lith` treats the records before the first explicit label
as the implicit `entry` block. Reachability propagates through `branch` and
`cbranch` successors and conservatively supports block fallthrough. The analysis
repeats for at most the number of blocks, which is sufficient to reach a fixed
point even when a reachable back-edge discovers an earlier label on a later
scan.

The pruning pass emits only reachable blocks. Reachable phi records are rebuilt
with incoming pairs from reachable predecessors, preventing stale predecessor
labels from surviving after block removal. The IR validator runs immediately
after this transform.

This replaces label-name-based cleanup as the correctness mechanism: an
ordinary `if.else` block made unreachable by constant branch folding is removed
just like a compiler-generated `dead.*` block.

## Indexed IR storage

Optimizer v2 keeps each function in one compact serialized arena and builds a
small integer record-start index for repeated middle-end access. This avoids
materializing per-record heap strings or rescanning the entire function for
every pass. Dead-value analysis now runs backward over the index and emits the
kept records in one forward pass.

The shared string-table helpers also avoid allocating temporary key/value
slices for every `map_get` probe; only a matched value is materialized. This is
important because symbol tables, validator state, optimizer alias maps, and CFG
reachability all use the same compact map representation.

On the self-host compiler workload used during this migration, peak memory fell
from roughly 631 MB to about 52 MB while preserving the fixed point. The number
is environment-specific and is documented as a development measurement rather
than a language guarantee.
