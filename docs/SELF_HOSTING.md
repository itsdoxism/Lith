# Lith self-hosting

Lith uses staged bootstraps so every self-host claim is executable rather than aspirational.

## Current LLVM bootstrap chain

The current compiler direction is LLVM IR, not C source.

1. Ordered source modules under `compiler/src/*.lith` are concatenated into `build/lithc.lith`.
2. The trusted Python LLVM backend (`compiler/lunac_llvm.py`, retained under its historical internal name) compiles that source to Stage 1 LLVM IR.
3. Clang turns Stage 1 IR plus `runtime/luna_runtime.ll` into a native Stage 1 compiler.
4. Stage 1 compiles the same Lith compiler source to Stage 2 LLVM IR.
5. Stage 2 produces Stage 3; Stage 3 produces Stage 4.
6. The self-host test requires Stage 2, Stage 3, and Stage 4 LLVM IR to be byte-for-byte identical.

Run the proof with:

```sh
make llvm-selfhost
```

## Normal user path

After one bootstrap:

```sh
make compiler
```

ordinary compilation is:

```text
.lith source -> build/lithc -> LLVM IR -> Clang/LLVM -> native binary
```

The public commands are:

```text
bin/lith
bin/lithc
```

The previous `bin/luna` and `bin/lunac` commands are temporary compatibility shims.

## Trusted base

A clean bootstrap currently trusts:

- Python for the initial trusted LLVM bootstrap backend;
- Clang/LLVM for lowering textual LLVM IR;
- `runtime/luna_runtime.ll` for the runtime surface.

The remaining `luna` names in bootstrap/runtime filenames and symbols are historical internal ABI names. Renaming those is intentionally separate from the public Lith migration so the rename does not invalidate the compiler bootstrap proof.

## Legacy C bootstrap

The older C-emitting compiler remains as a regression/recovery path and is not part of normal Lith compilation. `make selfhost` still exercises that historical fixed-point proof.

## Current self-hosted surface

The Lith-written LLVM compiler currently covers the public reference program plus typed pointers, allocation helpers, structs/member access, match returns, print interpolation, array literals, array indexing/assignment, and array iteration with loop control.

## Remaining work

The next compiler work should focus on semantic diagnostics/type errors and broadening feature parity. A later migration can rename the internal bootstrap filenames/runtime ABI after compatibility is no longer useful.
