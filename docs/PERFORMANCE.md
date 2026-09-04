# Lith performance profiles

Lith emits LLVM IR and uses Clang/LLVM for the final native binary. The public driver keeps `-O2` as the portable default and exposes stronger backend profiles explicitly.

## Driver profiles

Portable baseline:

```sh
./bin/lith app.lith -O2 -o app
```

Portable release build:

```sh
./bin/lith app.lith --release -o app
```

`--release` currently maps to `-O3`.

CPU-specific release build:

```sh
./bin/lith app.lith --release --native -o app
```

`--native` adds `-march=native`. This lets LLVM use instruction-set features available on the build machine, but the resulting binary may not run on older or different CPUs.

Explicit `-O0`, `-O1`, `-O2`, and `-O3` are also accepted. The default remains `-O2` so ordinary builds keep the previous behavior.

## Fair benchmarking

The benchmark runner applies the same backend optimization level to Lith and the equivalent C baseline:

```sh
python3 benchmarks/run.py --profile baseline
python3 benchmarks/run.py --profile release
python3 benchmarks/run.py --profile native
```

Profiles map to:

- `baseline`: Lith `-O2`, C `-O2`
- `release`: Lith `--release`, C `-O3`
- `native`: Lith `--release --native`, C `-O3 -march=native`

This is intentional: a Lith speedup is only interesting when C receives the equivalent backend tuning. Native tuning can help vectorizable CPU-heavy code substantially, while other workloads may stay flat or even regress slightly. Always compare multiple workloads rather than treating one microbenchmark as a universal result.

## Next compiler-side performance work

Backend flags are only the first layer. Future gains should come from better IR and stronger semantic information, for example:

- fewer unnecessary temporaries before LLVM optimization,
- explicit aliasing guarantees where Lith semantics can prove them,
- defined integer overflow semantics that allow safe optimization,
- better array and loop canonicalization for vectorization,
- runtime function attributes and cross-module optimization where toolchain support is reliable,
- profile-guided or target-specific optimization as optional modes.

The goal is C-class native performance without weakening benchmark fairness or silently changing program semantics.
