#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT="$ROOT/build/core-language"
mkdir -p "$OUT"

run_native() {
    source_file=$1
    output_name=$2
    exe="$OUT/$output_name"
    rm -f "$exe"
    "$ROOT/bin/lith" "$source_file" -o "$exe"
    "$exe"
}

check_compile_error() {
    source_file=$1
    name=$2
    expected=$3
    log="$OUT/$name.log"
    ir="$OUT/$name.ll"
    rm -f "$log" "$ir"

    if "$ROOT/bin/lithc" "$source_file" "$ir" >"$log" 2>&1; then
        echo "expected compiler failure for $source_file" >&2
        cat "$log" >&2
        exit 1
    fi
    if ! grep -F "$expected" "$log" >/dev/null; then
        echo "missing diagnostic '$expected' for $source_file" >&2
        cat "$log" >&2
        exit 1
    fi
    if [ -e "$ir" ]; then
        echo "compiler wrote LLVM IR for invalid source: $source_file" >&2
        exit 1
    fi
}

run_native "$ROOT/tests/core/core_values.lith" core-values
run_native "$ROOT/tests/core/module_main.lith" module-main

check_compile_error \
    "$ROOT/tests/core/bad_array_length.lith" \
    bad-array-length \
    'array literal length does not match its fixed array type'
check_compile_error \
    "$ROOT/tests/core/bad_array_overflow.lith" \
    bad-array-overflow \
    'too many values in array literal'
check_compile_error \
    "$ROOT/tests/core/bad_cast.lith" \
    bad-cast \
    'invalid explicit cast: str as int'
check_compile_error \
    "$ROOT/tests/core/bad_zero_call.lith" \
    bad-zero-call \
    'zero-argument call requires []'
check_compile_error \
    "$ROOT/tests/core/bad_recursive_struct.lith" \
    bad-recursive-struct \
    'infinite by-value struct layout involving Loop'
check_compile_error \
    "$ROOT/tests/core/bad_struct_literal.lith" \
    bad-struct-literal \
    'not enough values in struct literal'
check_compile_error \
    "$ROOT/tests/core/modules/cycle_a.lith" \
    module-cycle \
    'module import cycle:'
check_compile_error \
    "$ROOT/tests/core/module_missing.lith" \
    module-missing \
    'cannot read module:'
check_compile_error \
    "$ROOT/tests/core/module_bad_main.lith" \
    module-imported-diagnostic \
    'type mismatch: expected int, got str'

if ! grep -F 'tests/core/modules/bad_type.lith:2:' "$OUT/module-imported-diagnostic.log" >/dev/null; then
    echo 'imported diagnostic did not preserve module path + local line' >&2
    cat "$OUT/module-imported-diagnostic.log" >&2
    exit 1
fi

printf '%s\n' 'Core language completion checks: passed'
