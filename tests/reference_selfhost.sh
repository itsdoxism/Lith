#!/bin/sh
set -eu

BUILD=${BUILD:-build}
mkdir -p "$BUILD"

sh bin/luna examples/reference.luna -o "$BUILD/reference-selfhost"
actual=$("$BUILD/reference-selfhost")
expected='dynamic Token array created
items processed: 2
first token category: word'

if [ "$actual" != "$expected" ]; then
  echo 'self-hosted reference output mismatch' >&2
  echo '--- expected ---' >&2
  printf '%s\n' "$expected" >&2
  echo '--- actual ---' >&2
  printf '%s\n' "$actual" >&2
  exit 1
fi

echo 'Self-hosted reference program: passed'
