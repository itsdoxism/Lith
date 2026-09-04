#!/usr/bin/env sh
set -eu

PYTHON=${PYTHON:-python3}
CC=${CC:-cc}
CFLAGS=${CFLAGS:--std=c11 -O2 -Wall -Wextra -Wpedantic -Werror}
BUILD=${BUILD:-build/selfhost}

mkdir -p "$BUILD"

$PYTHON compiler/lunac.py compiler/lunac.luna "$BUILD/stage1.c"
$CC $CFLAGS -Iruntime "$BUILD/stage1.c" runtime/luna_runtime.c -o "$BUILD/lunac-stage1"

"$BUILD/lunac-stage1" compiler/lunac.luna "$BUILD/stage2.c"
$CC $CFLAGS -Iruntime "$BUILD/stage2.c" runtime/luna_runtime.c -o "$BUILD/lunac-stage2"

"$BUILD/lunac-stage2" compiler/lunac.luna "$BUILD/stage3.c"
$CC $CFLAGS -Iruntime "$BUILD/stage3.c" runtime/luna_runtime.c -o "$BUILD/lunac-stage3"

"$BUILD/lunac-stage3" compiler/lunac.luna "$BUILD/stage4.c"
cmp "$BUILD/stage2.c" "$BUILD/stage3.c"
cmp "$BUILD/stage3.c" "$BUILD/stage4.c"

echo "Luna self-host fixed point: OK"
