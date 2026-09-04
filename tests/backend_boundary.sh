#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

FRONTEND="
$ROOT/compiler/src/20_symbols.lith
$ROOT/compiler/src/30_operators.lith
$ROOT/compiler/src/30_core_values.lith
$ROOT/compiler/src/31_expressions.lith
$ROOT/compiler/src/40_memory_arrays.lith
$ROOT/compiler/src/50_match_print.lith
$ROOT/compiler/src/60_statements.lith
$ROOT/compiler/src/70_scanner.lith
$ROOT/compiler/src/75_global_constants.lith
$ROOT/compiler/src/80_emitter_main.lith
"

# Target-specific backend calls must stop at the IR boundary.
if grep -nH 'backend_' $FRONTEND; then
    echo 'frontend bypasses the Lith IR boundary' >&2
    exit 1
fi

# Concrete LLVM syntax belongs only in compiler/src/backend/llvm/.
if grep -nHE 'getelementptr|[[:space:]]icmp[[:space:]]|[[:space:]]fcmp[[:space:]]|=[[:space:]]alloca[[:space:]]|=[[:space:]]load[[:space:]]|[[:space:]]store[[:space:]].*,[[:space:]]ptr|[[:space:]]call[[:space:]].*@|^.*declare[[:space:]]|^.*define[[:space:]]|%struct\.|@luna_|@malloc|@realloc|@free|@puts' $FRONTEND; then
    echo 'LLVM syntax leaked into frontend/compiler semantics' >&2
    exit 1
fi

printf '%s\n' 'Backend boundary checks: passed'
