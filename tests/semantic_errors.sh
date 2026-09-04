#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT="$ROOT/build/semantic-errors"
mkdir -p "$OUT"

check_error() {
    file=$1
    expected=$2
    name=$(basename "$file" .lith)
    log="$OUT/$name.log"
    ir="$OUT/$name.ll"
    rm -f "$log" "$ir"

    if "$ROOT/bin/lithc" "$ROOT/tests/errors/$file" "$ir" >"$log" 2>&1; then
        echo "expected semantic failure for $file" >&2
        cat "$log" >&2
        exit 1
    fi

    if ! grep -F "$expected" "$log" >/dev/null; then
        echo "missing diagnostic for $file: $expected" >&2
        cat "$log" >&2
        exit 1
    fi
    if ! grep -F 'error: line ' "$log" >/dev/null; then
        echo "missing source line header for $file" >&2
        cat "$log" >&2
        exit 1
    fi
    if ! grep -F '^' "$log" >/dev/null; then
        echo "missing caret marker for $file" >&2
        cat "$log" >&2
        exit 1
    fi
    if [ -e "$ir" ]; then
        echo "compiler wrote LLVM IR for invalid program: $file" >&2
        exit 1
    fi
}

check_error type_mismatch.lith 'type mismatch: expected int, got str'
check_error bad_call.lith 'argument count mismatch: expected 2, got 1'
check_error break_outside.lith 'break used outside a loop'
check_error duplicate_local.lith 'duplicate local: value'
check_error bad_index.lith 'array or pointer index must be int, got str'

echo 'Semantic diagnostics: passed'
