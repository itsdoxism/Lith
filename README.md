# Luna

Luna is an experimental **zero-shift programming language** built around ergonomic 10-finger typing. Structural syntax avoids shifted punctuation where possible: blocks use `[` and `]`, strings use single quotes, and operators are words such as `add`, `sub`, `eq`, `lt`, `and`, and `or`.

## Current status

Luna is self-hosting. The normal native path is:

```text
Luna source -> self-hosted Luna compiler -> LLVM IR -> native binary
```

The canonical compiler implementation is now `compiler/lunac.luna`. C is no longer an intermediate in the normal path; the old C-emitting compiler and C runtime remain only as bootstrap/regression references.

The LLVM compiler reaches a textual self-host fixed point:

```text
stage2.ll == stage3.ll == stage4.ll
```

The current canonical compiler was locally validated at fixed point with SHA-256:

```text
82623acb09db0ca3435a0bd89117bc47ea05c9e01f373949a68a284072716b46
```

The self-hosted compiler covers the executable public reference program, including typed pointers, pointer indexing, `sys.alloc`/`realloc`/`free`, structs and member access, `while`, user functions, return-value `match / is / else`, and `io.print` interpolation for int/char/bool/str names.

## Build the compiler

Requirements:

- Python 3.10+ for the first bootstrap from a clean checkout
- Clang with LLVM IR support

Bootstrap once:

```sh
make compiler
```

This creates `build/lunac`. The build chain is:

```text
compiler/lunac.luna
        ↓ trusted Python LLVM bootstrap (Stage 1 only)
Stage 1 LLVM
        ↓ Clang
native Stage 1 Luna compiler
        ↓ compiles compiler/lunac.luna
Stage 2 LLVM
        ↓ Clang
build/lunac
```

After `build/lunac` exists, ordinary Luna compilation does not need Python.

## Compile Luna programs

```sh
./bin/luna hello.luna -o hello
./hello
```

Emit LLVM IR instead:

```sh
./bin/luna hello.luna --emit-llvm hello.ll
```

Use the compiler frontend directly:

```sh
./bin/lunac hello.luna hello.ll
```

`bin/luna` uses `build/lunac`, then asks Clang to lower the generated LLVM IR plus `runtime/luna_runtime.ll` into the final executable.

The public reference program passes through that same path:

```sh
make reference-selfhost
```

Expected output:

```text
dynamic Token array created
items processed: 2
first token category: word
```

## Tests

Self-host fixed point:

```sh
make llvm-selfhost
```

Verify that the historical split bootstrap source still reproduces the canonical compiler byte-for-byte:

```sh
make bootstrap-source-check
```

User-facing native smoke tests:

```sh
make driver-check
make reference-selfhost
```

Every regression, including the legacy C bootstrap path:

```sh
make test
```

## Repository layout

```text
bin/luna                              Luna source -> native driver
bin/lunac                             native self-hosted compiler launcher
compiler/lunac.luna                   canonical self-hosted LLVM compiler
compiler/lunac_llvm.py                trusted initial LLVM bootstrap
compiler/lunac.py                     trusted legacy C bootstrap compiler
compiler/bootstrap/lunac_c.luna       legacy self-hosted C-emitter source
compiler/bootstrap/lunac_llvm.part*   historical/recovery LLVM source fragments
compiler/bootstrap/build_reference_parity.py
                                      reproduces canonical source from fragments
runtime/luna_runtime.ll               current LLVM runtime module
runtime/luna_runtime.c                legacy C runtime
tests/llvm_self_host.sh               canonical LLVM fixed-point proof
tests/self_host.sh                    legacy C-emitter fixed-point proof
tests/reference_selfhost.sh           public reference through native Luna compiler
examples/reference.luna               executable language reference
```

## Next milestones

1. finish array literal/iteration parity beyond pointer-backed collections,
2. improve diagnostics, source locations, symbol/type checking, and malformed-program errors,
3. make modules/imports and the standard-library surface more deliberate,
4. simplify bootstrap/recovery artifacts while keeping the chain reproducible,
5. add package/project tooling and a cleaner user-facing compiler CLI,
6. optionally add object-file or direct machine-code emission if Luna should eventually stop depending on LLVM for final code generation.

See `docs/LANGUAGE.md` and `docs/SELF_HOSTING.md` for the language and bootstrap notes.
