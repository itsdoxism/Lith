<p align="center">
  <img src="assets/lith.svg" width="180" alt="Lith logo">
</p>

# Lith

Lith is an experimental programming language built around one simple idea: make code comfortable to type without constantly reaching for Shift.

Blocks use `[` and `]`, strings use single quotes, and many operators are words instead of symbols:

```lith
int total = 10 add 20

if [total gt 20] [
    io.print 'hello from Lith'
]
```

Lith is self-hosting. The compiler is written in Lith and produces LLVM IR, which is then turned into a native binary with Clang.

```text
Lith source -> Lith compiler -> LLVM IR -> native binary
```

## Build

You need Clang/LLVM and a trusted Lith compiler seed.

The default seed location is:

```text
bootstrap/seed/lithc-linux-x86_64
```

You can also provide one explicitly:

```sh
LITH_SEED=/path/to/lithc make compiler
```

Once built, the compiler and native driver are available under `build/`.

## Compile a program

```sh
./bin/lith hello.lith -o hello
./hello
```

Emit LLVM IR instead:

```sh
./bin/lith hello.lith --emit-llvm hello.ll
```

Or use the compiler frontend directly:

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

## Tests

```sh
make test
```

There are also smaller targets for the compiler pipeline, native driver, language semantics, and runtime surfaces if you only want to check one area while working on Lith.

## Repository

```text
compiler/src/        self-hosted compiler
runtime/             LLVM runtime modules
bin/lith             Lith command-line launcher
bin/lithc            compiler launcher
tools/               Lith-native build and tooling programs
tests/               compiler and language tests
examples/            example Lith programs
editors/vscode/      VS Code grammar and Lith Obsidian theme
assets/              project artwork
```

Lith was previously called Luna, so a few compatibility names still exist internally while the migration is being finished.

More details are in `docs/LANGUAGE.md`, `docs/ARCHITECTURE.md`, and `docs/SELF_HOSTING.md`.
