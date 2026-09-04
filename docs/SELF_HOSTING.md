# Luna self-hosting

Luna uses staged bootstraps so the trusted base stays small and every self-host claim is executable rather than aspirational.

## LLVM bootstrap chain

The current compiler direction is LLVM IR, not C source.

1. `compiler/lunac_llvm.py` compiles the Luna LLVM compiler source to Stage 1 LLVM IR.
2. Clang turns Stage 1 IR plus `runtime/luna_runtime.ll` into a native compiler.
3. That native Luna compiler compiles its own Luna source to Stage 2 LLVM IR.
4. Stage 2 is built and used to produce Stage 3 LLVM IR.
5. Stage 3 is built and used to produce Stage 4 LLVM IR.
6. The test requires Stage 2, Stage 3, and Stage 4 IR to be byte-for-byte identical.

The self-hosted LLVM compiler source is split across:

```text
compiler/bootstrap/lunac_llvm.part1.luna
compiler/bootstrap/lunac_llvm.part2.luna
compiler/bootstrap/lunac_llvm.part3.luna
```

The test harness concatenates those files before bootstrapping.

Run the LLVM fixed-point proof with:

```sh
make llvm-selfhost
```

## Legacy C bootstrap chain

The older proof remains intentionally available as a regression path:

1. `compiler/lunac.py` compiles `compiler/lunac.luna` to Stage 1 C.
2. Stage 1 C is linked with `runtime/luna_runtime.c`.
3. The resulting native compiler produces Stage 2 C.
4. Stage 2 produces Stage 3 C.
5. Stage 3 produces Stage 4 C.
6. Stage 2, Stage 3, and Stage 4 C must be byte-for-byte identical.

Run it with:

```sh
make selfhost
```

## Why the fixed point matters

Stage 1 is produced by a trusted bootstrap implementation. Stage 2 and later are produced by the compiler written in Luna itself. Reaching a stable Stage 2/3/4 output proves that later compiler generations no longer depend on changes introduced by the bootstrap implementation.

## Trusted base

For a fresh LLVM bootstrap Luna currently trusts:

- Python for the initial `compiler/lunac_llvm.py` bootstrap step;
- Clang/LLVM to lower generated LLVM IR into machine code;
- `runtime/luna_runtime.ll` for the small file/string runtime surface.

A C compiler is not required for the LLVM native path. It is only needed when running the legacy C bootstrap/regression tests.

## Remaining work

Self-hosting does not imply full language feature parity. The next work is to move remaining Stage-0-only features into the self-hosted LLVM compiler, promote that compiler to the normal user-facing `lunac`, and reduce Python to bootstrap-only status. A later direct object-code or machine-code backend could remove the final LLVM dependency as well.
