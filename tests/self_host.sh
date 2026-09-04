#!/usr/bin/env sh
set -eu

PYTHON=${PYTHON:-python3}
CC=${CC:-cc}
CFLAGS=${CFLAGS:--std=c11 -O2 -Wall -Wextra -Wpedantic -Werror}
BUILD=${BUILD:-build/selfhost}
LEGACY_SRC=${LEGACY_SRC:-compiler/bootstrap/lunac_c.luna}

mkdir -p "$BUILD"

$PYTHON compiler/lunac.py "$LEGACY_SRC" "$BUILD/stage1.c"
$CC $CFLAGS -Iruntime "$BUILD/stage1.c" runtime/luna_runtime.c -o "$BUILD/lunac-stage1"

"$BUILD/lunac-stage1" "$LEGACY_SRC" "$BUILD/stage2.c"
$CC $CFLAGS -Iruntime "$BUILD/stage2.c" runtime/luna_runtime.c -o "$BUILD/lunac-stage2"

"$BUILD/lunac-stage2" "$LEGACY_SRC" "$BUILD/stage3.c"
$CC $CFLAGS -Iruntime "$BUILD/stage3.c" runtime/luna_runtime.c -o "$BUILD/lunac-stage3"

"$BUILD/lunac-stage3" "$LEGACY_SRC" "$BUILD/stage4.c"
cmp "$BUILD/stage2.c" "$BUILD/stage3.c"
cmp "$BUILD/stage3.c" "$BUILD/stage4.c"

echo 'Legacy C-emitter self-host fixed point: OK'
