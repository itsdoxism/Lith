#!/bin/sh
set -eu

PYTHON=${PYTHON:-python3}
CLANG=${CLANG:-clang}
BUILD=${BUILD:-build/llvm-selfhost}
LLVM_LUNAC=${LLVM_LUNAC:-compiler/lunac_llvm.py}
LLVM_RUNTIME=${LLVM_RUNTIME:-runtime/luna_runtime.ll}
BOOTSTRAP_GEN=${BOOTSTRAP_GEN:-compiler/bootstrap/build_reference_parity.py}

mkdir -p "$BUILD"
SRC="$BUILD/lunac_llvm.luna"
"$PYTHON" "$BOOTSTRAP_GEN" "$SRC"

# Stage 1 is bootstrapped by the trusted Python LLVM backend.
"$PYTHON" "$LLVM_LUNAC" "$SRC" "$BUILD/stage1.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/stage1.ll" "$LLVM_RUNTIME" -o "$BUILD/stage1"

# From here on, every compiler is produced by a Luna compiler.
"$BUILD/stage1" "$SRC" "$BUILD/stage2.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/stage2.ll" "$LLVM_RUNTIME" -o "$BUILD/stage2"

"$BUILD/stage2" "$SRC" "$BUILD/stage3.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/stage3.ll" "$LLVM_RUNTIME" -o "$BUILD/stage3"

"$BUILD/stage3" "$SRC" "$BUILD/stage4.ll"

# Reference-parity additions must preserve the self-host fixed point.
cmp "$BUILD/stage2.ll" "$BUILD/stage3.ll"
cmp "$BUILD/stage3.ll" "$BUILD/stage4.ll"

if command -v sha256sum >/dev/null 2>&1; then
  hash=$(sha256sum "$BUILD/stage2.ll" | awk '{print $1}')
  echo "LLVM self-host fixed point: $hash"
else
  echo 'LLVM self-host fixed point reached'
fi
