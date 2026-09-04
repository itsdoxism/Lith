# Luna

Luna is an experimental **zero-shift programming language** built around ergonomic 10-finger typing. Structural syntax avoids shifted punctuation where possible: blocks use `[` and `]`, strings use single quotes, and operators are words such as `add`, `sub`, `eq`, `lt`, `and`, and `or`.

## Current status

This repository now contains a working Stage-0 compiler:

```text
.luna source -> compiler/lunac.py -> generated C -> native executable
```

The compiler currently handles the core language used by the reference program: functions, structs, typed variables, pointer allocation helpers, member/index access, arrays, textual operators, `while`, `loop`, match-style `if`/`is`/`else`, no-parentheses function calls, and string interpolation for `io.print`.

## Try it

Requirements: Python 3.10+ and a C11 compiler.

```sh
make test
```

Or compile manually:

```sh
python3 compiler/lunac.py examples/reference.luna build/reference.c
cc -std=c11 -Wall -Wextra -Wpedantic -Werror build/reference.c -o build/reference
./build/reference
```

## Direction

The compiler is intentionally staged. Stage 0 is a small trusted bootstrap compiler. The long-term target is self-hosting: implement the compiler in Luna, compile it with Stage 0, then compile that compiler with itself and compare the stages.

See `docs/LANGUAGE.md` for the current language notes.