#!/bin/sh
set -eu

BUILD=${BUILD:-build/native-surfaces}
LITH=${LITH:-bin/lith}

mkdir -p "$BUILD"
OUT="$BUILD/native-surfaces"

sh "$LITH" tests/core/native_surfaces.lith -o "$OUT"
"$OUT"

echo 'Lith text/binary fs + path + bytes + process native surfaces: passed'
