# Lith

Lith is an experimental **zero-shift programming language** built around ergonomic 10-finger typing. Structural syntax avoids shifted punctuation where possible: blocks use `[` and `]`, strings use single quotes, and operators are words such as `add`, `sub`, `eq`, `lt`, `and`, and `or`.

> Lith was previously named **Luna**. The public CLI and source extension are now `lith`, `lithc`, and `.lith`. The old `luna`/`lunac` commands remain as temporary compatibility shims.

## Current status

Lith is self-hosting and its native path is:

```text
Lith source -> self-hosted Lith compiler -> LLVM IR -> native binary
```

C is not an intermediate in the normal LLVM path. The old C bootstrap remains only as a regression/recovery path.

The self-hosted compiler currently covers the executable reference surface plus:

- typed pointers and pointer indexing
- `sys.alloc`, `sys.realloc`, and `sys.free`
- structs and member loads/stores
- return-value `match / is / else`
- `io.print` interpolation
- array literals such as `arr values = [1, 2, 3]`
- array indexing and assignment
- `loop item in values` with `break` / `continue`

The compiler source is split into ordered Lith modules under `compiler/src/` and concatenated deterministically for bootstrap/self-hosting.

## Build

Requirements:

- Python 3.10+ for the initial trusted bootstrap from a clean checkout
- Clang with LLVM IR support

```sh
make compiler
```

This produces:

```text
build/lithc
```

After that, ordinary Lith compilation does not need Python.

## Compile Lith programs

```sh
./bin/lith hello.lith -o hello
./hello
```

Emit LLVM IR:

```sh
./bin/lith hello.lith --emit-llvm hello.ll
```

Use the compiler frontend directly:

```sh
./bin/lithc hello.lith hello.ll
```

The old commands still forward to the new names during migration:

```sh
./bin/luna  # deprecated -> lith
./bin/lunac # deprecated -> lithc
```

## Example

```lith
arr values = [10, 20, 30]
values[1] = 25

loop item in values [
    io.print 'value: [item]'
]
```

## Tests

```sh
make driver-check
make reference-selfhost
make llvm-selfhost
make test
```

`make test` also runs the older C bootstrap regression path.

## Repository layout

```text
bin/lith                     Lith source -> native driver
bin/lithc                    native self-hosted compiler launcher
compiler/src/*.lith          current self-hosted compiler source modules
compiler/lunac_llvm.py       trusted Python LLVM bootstrap backend (legacy internal name)
compiler/lunac.py            trusted C bootstrap backend (legacy internal name)
runtime/luna_runtime.ll      current runtime ABI (legacy internal name)
examples/reference.lith      executable language reference
tests/*.lith                 language/runtime fixtures
```

The remaining `luna`/`lunac` names are internal bootstrap/compatibility names and can be retired separately after the public migration is stable.

## Next milestones

1. finish semantic diagnostics and type errors,
2. expand arrays and `match` beyond the current self-hosted surface,
3. grow the standard library/runtime,
4. reduce Python further toward recovery/bootstrap-only status,
5. optionally add direct object-code or machine-code generation later.

See `docs/LANGUAGE.md` and `docs/SELF_HOSTING.md` for details.
