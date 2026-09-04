#!/bin/sh
set -eu

PYTHON=${PYTHON:-python3}
CLANG=${CLANG:-clang}
BUILD=${BUILD:-build/llvm-selfhost}
LLVM_LUNAC=${LLVM_LUNAC:-compiler/lunac_llvm.py}
LLVM_RUNTIME=${LLVM_RUNTIME:-runtime/luna_runtime.ll}

mkdir -p "$BUILD"
SRC="$BUILD/lunac_llvm.luna"
cat \
  compiler/bootstrap/lunac_llvm.part1.luna \
  compiler/bootstrap/lunac_llvm.part2.luna \
  compiler/bootstrap/lunac_llvm.part3.memory.luna \
  > "$SRC"

# Stage 1 is bootstrapped by the trusted Python LLVM backend.
"$PYTHON" "$LLVM_LUNAC" "$SRC" "$BUILD/stage1.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/stage1.ll" "$LLVM_RUNTIME" -o "$BUILD/stage1"

# From here on, every compiler is produced by a Luna compiler.
"$BUILD/stage1" "$SRC" "$BUILD/stage2.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/stage2.ll" "$LLVM_RUNTIME" -o "$BUILD/stage2"

"$BUILD/stage2" "$SRC" "$BUILD/stage3.ll"
"$CLANG" -Wno-override-module -O2 "$BUILD/stage3.ll" "$LLVM_RUNTIME" -o "$BUILD/stage3"

"$BUILD/stage3" "$SRC" "$BUILD/stage4.ll"

# A stable compiler must reach a textual IR fixed point after the memory parity change.
cmp "$BUILD/stage2.ll" "$BUILD/stage3.ll"
cmp "$BUILD/stage3.ll" "$BUILD/stage4.ll"

if command -v sha256sum >/dev/null 2>&1; then
  hash=$(sha256sum "$BUILD/stage2.ll" | awk '{print $1}')
  echo "LLVM self-host fixed point: $hash"
else
  echo 'LLVM self-host fixed point reached'
fi
