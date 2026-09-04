# Lith benchmarks

This directory contains small, reproducible microbenchmarks for the current Lith native pipeline.

The initial baseline compares Lith with C because both can be compiled through the same `clang -O2` backend. That makes the comparison useful for checking whether Lith's generated LLVM IR is carrying avoidable runtime overhead, while also keeping backend differences out of the result.

Cases:

- `empty`: process startup / minimum binary overhead
- `loop`: 40 million runtime-dependent integer loop iterations with modulo arithmetic
- `array`: dynamic local-array indexing, loads and stores
- `alloc`: one-million-element heap allocation, fill, scan and free

Run from the repository root:

```sh
python3 benchmarks/run.py
```

The runner bootstraps `build/lithc` if needed, builds equivalent Lith and C programs, checks output equality for the compute cases, then reports median runtime, compile latency, frontend-to-LLVM latency and binary size.

These are microbenchmarks, not a claim that Lith is universally as fast as C. Results vary by CPU, OS and compiler version. Real application benchmarks should be added as the standard library grows.
