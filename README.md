# Luna

Luna is an experimental **zero-shift programming language** built around ergonomic 10-finger typing. Structural syntax avoids shifted punctuation where possible: blocks use `[` and `]`, strings use single quotes, and operators are words such as `add`, `sub`, `eq`, `lt`, `and`, and `or`.

## Current status

Luna is now self-hosting and has a **C-free LLVM native path**.

The project keeps two bootstrap tracks on purpose:

```text
legacy bootstrap:
Luna -> C -> native

current native path:
Luna -> LLVM IR -> native
```

The trusted bootstrap implementations are still kept in Python so a fresh checkout can rebuild the compiler from a conventional host toolchain. The important part is that the compiler implementation itself also exists in Luna and reaches a fixed point when it compiles itself.

### LLVM self-host chain

The self-hosted LLVM compiler source is stored in `compiler/bootstrap/lunac_llvm.part*.luna` and reconstructed by the test harness:

```text
Luna LLVM compiler source
        |
        v
Python LLVM bootstrap -> stage1.ll -> native stage1
                                      |
                                      v
                                  stage2.ll -> native stage2
                                      |
                                      v
                                  stage3.ll -> native stage3
                                      |
                                      v
                                  stage4.ll
```

The test verifies:

```text
stage2.ll == stage3.ll == stage4.ll
```

That textual LLVM IR fixed point is the bootstrap proof for the LLVM-emitting compiler.

The older C-emitting self-hosted compiler remains in `compiler/lunac.luna` as a regression/bootstrap reference. It also has its own Stage 2/3/4 fixed-point test.

## Try it

Requirements for the current path:

- Python 3.10+ for the initial trusted bootstrap
- Clang with LLVM IR support

Build and run the LLVM-backed reference program:

```sh
make
./build/reference-llvm
```

Or explicitly:

```sh
make llvm
```

Run the LLVM self-host fixed-point proof:

```sh
make llvm-selfhost
```

Run every regression, including the older C bootstrap path:

```sh
make test
```

## Repository layout

```text
compiler/lunac.py                         trusted C bootstrap compiler
compiler/lunac.luna                       self-hosted C-emitting Luna compiler
compiler/lunac_llvm.py                    trusted LLVM bootstrap backend
compiler/bootstrap/lunac_llvm.part*.luna  self-hosted LLVM-emitting compiler source
runtime/luna_runtime.c                    legacy/bootstrap C runtime
runtime/luna_runtime.ll                   LLVM runtime module
tests/self_host.sh                        C emitter fixed-point proof
tests/llvm_backend.sh                     LLVM backend transition/runtime checks
tests/llvm_self_host.sh                   LLVM emitter fixed-point proof
examples/reference.luna                   executable language reference
```

## Direction

The C intermediate is no longer required by Luna's current native backend. Clang/LLVM is still used to turn generated LLVM IR into machine code.

The next milestones are:

1. move remaining Stage-0-only language features into the self-hosted LLVM compiler,
2. make the Luna LLVM compiler the normal user-facing `lunac`,
3. shrink Python to a bootstrap-only artifact,
4. eventually add object-file or direct machine-code emission if Luna should also stop depending on LLVM for final code generation.

See `docs/LANGUAGE.md` and `docs/SELF_HOSTING.md` for the language and bootstrap notes.
