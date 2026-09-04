# Luna

Luna is an experimental **zero-shift programming language** built around ergonomic 10-finger typing. Structural syntax avoids shifted punctuation where possible: blocks use `[` and `]`, strings use single quotes, and operators are words such as `add`, `sub`, `eq`, `lt`, `and`, and `or`.

## Current status

Luna is self-hosting and its current native path is:

```text
Luna source -> self-hosted Luna compiler -> LLVM IR -> native binary
```

C is no longer an intermediate in the normal LLVM path. The older C-emitting compiler and C runtime remain in the repository only as bootstrap/regression references.

The LLVM-emitting compiler reaches a textual fixed point during self-compilation:

```text
stage2.ll == stage3.ll == stage4.ll
```

That is the executable bootstrap proof that the Luna-written compiler can reproduce itself.

The self-hosted LLVM compiler now also supports the first broader feature-parity slice: typed pointers, pointer indexing, and `sys.alloc`, `sys.realloc`, and `sys.free`. Allocation sizes are derived from the declared pointer element type in generated LLVM IR rather than using a fixed byte multiplier.

## Build the compiler

Requirements:

- Python 3.10+ only for the first bootstrap from a clean checkout
- Clang with LLVM IR support

Bootstrap the native compiler once:

```sh
make compiler
```

This creates:

```text
build/lunac
```

The build chain is:

```text
trusted Python LLVM bootstrap
        -> stage1 LLVM
        -> native stage1 Luna compiler
        -> stage2 LLVM
        -> build/lunac
```

After `build/lunac` exists, ordinary Luna compilation no longer needs Python.

## Compile Luna programs

Compile directly to a native executable:

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

`bin/luna` uses the self-hosted `build/lunac` compiler and then asks Clang to turn the generated LLVM IR plus `runtime/luna_runtime.ll` into the final executable.

## Tests

Run the LLVM self-host fixed-point proof:

```sh
make llvm-selfhost
```

Run the user-facing native driver and pointer-memory smoke test:

```sh
make driver-check
```

Run every regression, including the older C bootstrap path:

```sh
make test
```

## Repository layout

```text
bin/luna                              Luna source -> native driver
bin/lunac                             native self-hosted compiler launcher
compiler/lunac.py                     trusted legacy C bootstrap compiler
compiler/lunac.luna                   older self-hosted C-emitting compiler
compiler/lunac_llvm.py                trusted LLVM bootstrap backend
compiler/bootstrap/lunac_llvm.part*   self-hosted LLVM-emitting compiler source
runtime/luna_runtime.c                legacy/bootstrap C runtime
runtime/luna_runtime.ll               current LLVM runtime module
tests/self_host.sh                    legacy C emitter fixed-point proof
tests/llvm_backend.sh                 LLVM backend transition/runtime checks
tests/llvm_self_host.sh               LLVM emitter fixed-point proof
tests/selfhost_memory.luna            pointer allocation/reallocation/free fixture
examples/reference.luna               executable language reference
```

## Next milestones

1. continue self-hosted LLVM feature parity with `struct` + member access,
2. add array literals/iteration and `match`,
3. add the full `io.print` interpolation surface,
4. consolidate the split bootstrap source into the canonical Luna compiler source,
5. reduce Python to a bootstrap-only recovery artifact,
6. grow the standard library/runtime surface,
7. optionally add object-file or direct machine-code emission later if Luna should stop depending on LLVM for final code generation too.

See `docs/LANGUAGE.md` and `docs/SELF_HOSTING.md` for the language and bootstrap notes.
