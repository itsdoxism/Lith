#!/bin/sh
set -eu

PYTHON=${PYTHON:-python3}
CLANG=${CLANG:-clang}
BUILD=${BUILD:-build/llvm}
LLVM_LUNAC=${LLVM_LUNAC:-compiler/lunac_llvm.py}
C_LUNAC=${C_LUNAC:-compiler/lunac.py}
LLVM_RUNTIME=${LLVM_RUNTIME:-runtime/luna_runtime.ll}

mkdir -p "$BUILD"

# 1) Current language reference: Luna -> LLVM IR -> native, with no C intermediate.
"$PYTHON" "$LLVM_LUNAC" examples/reference.luna "$BUILD/reference.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/reference.ll" "$LLVM_RUNTIME" -o "$BUILD/reference"
reference_output=$($BUILD/reference)
expected_reference='dynamic Token array created
items processed: 2
first token category: word'
[ "$reference_output" = "$expected_reference" ]

# 2) Exercise the string/file-facing LLVM runtime surface used by the compiler.
"$PYTHON" "$LLVM_LUNAC" tests/llvm_runtime.luna "$BUILD/runtime_test.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/runtime_test.ll" "$LLVM_RUNTIME" -o "$BUILD/runtime_test"
runtime_output=$($BUILD/runtime_test)
[ "$runtime_output" = 'a=hello n=5 eq=1 starts=1 cut=ell ch=! num=42' ]

# 3) Transition proof: build the existing self-hosted Luna compiler through LLVM.
#    Then execute that LLVM-built compiler and compare its generated C against
#    the trusted Stage-0 compiler. This proves the compiler itself runs correctly
#    when its machine code came from the LLVM path.
"$PYTHON" "$LLVM_LUNAC" compiler/lunac.luna "$BUILD/lunac.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/lunac.ll" "$LLVM_RUNTIME" -o "$BUILD/lunac"
"$PYTHON" "$C_LUNAC" compiler/lunac.luna "$BUILD/from_stage0.c"
"$BUILD/lunac" compiler/lunac.luna "$BUILD/from_llvm_native.c"
cmp "$BUILD/from_stage0.c" "$BUILD/from_llvm_native.c"

echo 'LLVM backend: reference, runtime, and self-host transition checks passed'
