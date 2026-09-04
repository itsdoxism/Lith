#!/bin/sh
set -eu

BUILD=${BUILD:-build/ir-middle-end}
LITHC=${LITHC:-bin/lithc}
CLANG=${CLANG:-clang}
LLVM_RUNTIME=${LLVM_RUNTIME:-runtime/luna_runtime.ll}

mkdir -p "$BUILD"
IR="$BUILD/optimizer.ll"
BIN="$BUILD/optimizer"

"$LITHC" tests/core/ir_optimizer.lith "$IR"

# The Lith middle-end should fold both the integer expression and the
# compile-time condition before LLVM lowering sees them.
grep -q 'store i32 5' "$IR"
if grep -q 'add i32 2, 3' "$IR"; then
    echo 'IR optimizer failed to fold integer addition' >&2
    exit 1
fi
if grep -q 'icmp .* i32 1, 1' "$IR"; then
    echo 'IR optimizer failed to fold constant comparison' >&2
    exit 1
fi
if grep -q 'br i1 1' "$IR"; then
    echo 'IR optimizer failed to simplify constant conditional branch' >&2
    exit 1
fi
grep -q 'br label %if.then' "$IR"

"$CLANG" -Wno-override-module -O2 "$IR" "$LLVM_RUNTIME" -o "$BIN"
set +e
"$BIN"
rc=$?
set -e
if [ "$rc" -ne 5 ]; then
    echo "optimized program returned $rc, expected 5" >&2
    exit 1
fi

# Keep the validator wired before and after optimization. This catches an
# accidental bypass even though ordinary source cannot directly construct
# malformed internal records.
grep -q 'ir_validate_function g_ir_code' compiler/src/25_ir.lith
grep -q 'ir_validate_function optimized' compiler/src/25_ir.lith

echo 'Lith IR validator + optimizer: passed'
