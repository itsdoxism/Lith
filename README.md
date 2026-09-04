# Luna

Luna is an experimental **zero-shift programming language** built around ergonomic 10-finger typing. Structural syntax avoids shifted punctuation where possible: blocks use `[` and `]`, strings use single quotes, and operators are words such as `add`, `sub`, `eq`, `lt`, `and`, and `or`.

## Current status

Luna now has a **self-hosting bootstrap compiler**.

The trusted Stage-0 compiler is still `compiler/lunac.py`, but the compiler implementation also exists in Luna as `compiler/lunac.luna`:

```text
compiler/lunac.luna
        |
        v
Stage 0 (Python) -> stage1 C -> native lunac-stage1
                                |
                                v
                         stage2 C -> lunac-stage2
                                |
                                v
                         stage3 C -> lunac-stage3
```

The self-host test then compiles the compiler one more time and verifies that Stage 2, Stage 3, and Stage 4 generated C are byte-for-byte identical. That fixed point is the bootstrap proof that the Luna compiler can compile its own source.

The self-hosted compiler currently implements the **bootstrap subset** needed to compile itself: globals, functions, typed parameters and returns, string/int/bool expressions, textual operators, calls, indexing, `if`/`else`, `while`, `break`, `continue`, file I/O, and bootstrap string helpers. Stage 0 still supports some features that have not yet been ported into the self-hosted compiler, including the complete reference-program surface such as structs, arrays, match expressions, and allocation helpers.

## Try it

Requirements: Python 3.10+ and a C11 compiler.

```sh
make test
```

`make test` runs both the existing executable language reference and the self-hosting fixed-point proof.

To run only the bootstrap proof:

```sh
make selfhost
```

## Repository layout

```text
compiler/lunac.py       trusted Stage-0 bootstrap compiler
compiler/lunac.luna     self-hosted Luna compiler
runtime/                 small C runtime used by generated programs
tests/self_host.sh      Stage 1 -> 2 -> 3 -> 4 fixed-point test
examples/reference.luna broader Stage-0 language reference
```

## Direction

Self-hosting is no longer the future target; it is working now. The next compiler milestone is **feature parity**: move the remaining Stage-0-only language features into `compiler/lunac.luna`, then shrink the Python bootstrap compiler until it is only needed for the initial bootstrap chain.

See `docs/LANGUAGE.md` and `docs/SELF_HOSTING.md` for details.
