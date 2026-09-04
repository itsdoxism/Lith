# Luna self-hosting

Luna uses a staged bootstrap so the trusted base stays explicit and every self-host claim is executable rather than aspirational.

## Canonical compiler source

The source of truth for the current compiler is:

```text
compiler/lunac.luna
```

It is a Luna program that emits LLVM IR. Normal compiler builds and the LLVM fixed-point test compile this file directly; they do not generate the compiler source first.

The older split LLVM source fragments and `compiler/bootstrap/build_reference_parity.py` remain as bootstrap-history/recovery artifacts. They must reproduce `compiler/lunac.luna` byte-for-byte:

```sh
make bootstrap-source-check
```

## LLVM bootstrap chain

1. `compiler/lunac_llvm.py` compiles `compiler/lunac.luna` to Stage 1 LLVM IR.
2. Clang links Stage 1 IR with `runtime/luna_runtime.ll` to create a native Stage 1 compiler.
3. Stage 1 compiles `compiler/lunac.luna` to Stage 2 LLVM IR.
4. Stage 2 is built and produces Stage 3 LLVM IR.
5. Stage 3 is built and produces Stage 4 LLVM IR.
6. The test requires Stage 2, Stage 3, and Stage 4 IR to be byte-for-byte identical.

Run the proof with:

```sh
make llvm-selfhost
```

The current validated fixed-point SHA-256 is:

```text
82623acb09db0ca3435a0bd89117bc47ea05c9e01f373949a68a284072716b46
```

The public reference program is also compiled with the resulting native self-hosted compiler:

```sh
make reference-selfhost
```

## Legacy C bootstrap chain

The former self-hosted C-emitting compiler is preserved at:

```text
compiler/bootstrap/lunac_c.luna
```

It remains a regression proof, not the normal Luna compiler path:

1. `compiler/lunac.py` compiles `compiler/bootstrap/lunac_c.luna` to Stage 1 C.
2. Stage 1 C is linked with `runtime/luna_runtime.c`.
3. The native Stage 1 compiler produces Stage 2 C.
4. Stage 2 produces Stage 3 C.
5. Stage 3 produces Stage 4 C.
6. Stage 2/3/4 C must be byte-for-byte identical.

Run it with:

```sh
make selfhost
```

## Why the fixed point matters

Stage 1 is produced by a trusted bootstrap implementation. Stage 2 and later are produced by the compiler written in Luna itself. A stable Stage 2/3/4 output shows that the Luna-written compiler can reproduce the same compiler generation repeatedly instead of depending on incidental transformations from Stage 0.

A fixed point is a bootstrap/reproducibility proof; it does not by itself prove semantic correctness or full language coverage. Those are covered by executable language tests such as `make reference-selfhost` and other fixtures.

## Trusted base

For a fresh normal LLVM bootstrap Luna currently trusts:

- Python for the initial `compiler/lunac_llvm.py` Stage 1 step;
- Clang/LLVM to lower generated LLVM IR into machine code;
- `runtime/luna_runtime.ll` for the small runtime surface.

After `build/lunac` exists, compiling ordinary Luna source does not require Python. A C compiler is required only for the legacy C regression path.

## Current direction

The next priorities are language/compiler quality rather than another bootstrap rewrite: array parity, stronger diagnostics and type checking, modules/standard-library design, and project/package tooling. A later object-code or direct machine-code backend could remove the final LLVM dependency if that becomes a design goal.
