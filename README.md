<p align="center">
  <img src="assets/lith.svg" width="180" alt="Lith logo">
</p>

# Lith

Lith is an experimental, self-hosted programming language designed around comfortable 10-finger typing.

Instead of relying heavily on shifted punctuation, Lith uses square brackets for structure, single-quoted strings, and readable word operators such as `add`, `sub`, `eq`, `lt`, `and`, and `or`.

```lith
int total = 10 add 20

if [total gt 20] [
    io.print 'hello from Lith'
]
```

Lith compiles to native code through LLVM:

```text
Lith source -> Lith compiler -> LLVM IR -> Clang/LLVM -> native binary
```

## Features

- self-hosted compiler written in Lith
- native compilation through LLVM
- word-based arithmetic and comparison operators
- arrays, structs, pointers, loops, and pattern matching
- manual memory management primitives
- filesystem, path, bytes, and process runtime APIs
- VS Code syntax highlighting and the Lith Obsidian theme

## Build

Lith currently requires Clang/LLVM and a trusted Lith compiler seed.

The conventional seed location is:

```text
bootstrap/seed/lithc-linux-x86_64
```

A seed can also be provided explicitly:

```sh
LITH_SEED=/path/to/lithc make compiler
```

The build produces the self-hosted compiler and native driver under `build/`.

## Compile a program

```sh
./bin/lith hello.lith -o hello
./hello
```

To emit LLVM IR:

```sh
./bin/lith hello.lith --emit-llvm hello.ll
```

The compiler frontend can also be used directly:

```sh
./bin/lithc hello.lith hello.ll
```

## Example

```lith
arr values = [10, 20, 30]
values[1] = 25

loop item in values [
    io.print 'value: [item]'
]
```

## Testing

Run the main test suite with:

```sh
make test
```

Smaller Make targets are available for individual compiler, language, runtime, and driver checks during development.

## Documentation

- [`docs/LANGUAGE.md`](docs/LANGUAGE.md) — language syntax and semantics
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — compiler architecture
- [`docs/SELF_HOSTING.md`](docs/SELF_HOSTING.md) — self-hosting and bootstrap model

## Repository layout

```text
compiler/src/        self-hosted compiler
runtime/             LLVM runtime modules
bin/                 command-line launchers
tools/               Lith-native build tools
tests/               compiler and language tests
examples/            example Lith programs
editors/vscode/      VS Code language support
assets/              project artwork
```

## Contributing

Lith is still experimental, so compiler bugs, language edge cases, runtime issues, documentation improvements, and editor tooling are all useful contributions.

Please keep changes focused and include tests where the behavior can be covered.

---

Lith was previously called **Luna**. A few compatibility names may still appear internally while that migration is being completed.
