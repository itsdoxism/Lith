#!/bin/sh
set -eu

BUILD=${BUILD:-build/bench}
TIME_BIN=${TIME_BIN:-/usr/bin/time}
mkdir -p "$BUILD"

if [ ! -x "$TIME_BIN" ]; then
    echo "GNU time not found at $TIME_BIN" >&2
    exit 1
fi

report_time() {
    label=$1
    file=$2
    elapsed=$(grep 'Elapsed (wall clock) time' "$file" | sed 's/^[^:]*:[[:space:]]*//' || true)
    rss_kb=$(grep 'Maximum resident set size (kbytes)' "$file" | awk '{print $6}' || true)
    user_s=$(grep 'User time (seconds)' "$file" | awk '{print $4}' || true)
    sys_s=$(grep 'System time (seconds)' "$file" | awk '{print $4}' || true)
    printf '%-24s elapsed=%-10s peak_rss=%-10s KB user=%-8s sys=%-8s\n' "$label" "$elapsed" "$rss_kb" "$user_s" "$sys_s"
}

printf '\nLith benchmark\n==============\n'
printf 'branch/head: '
git rev-parse --short HEAD 2>/dev/null || echo unknown
printf '\n'

rm -rf build
mkdir -p "$BUILD"

"$TIME_BIN" -v make compiler >"$BUILD/compiler.stdout" 2>"$BUILD/compiler.time"
report_time 'compiler build' "$BUILD/compiler.time"
if [ -f build/lithc ]; then
    printf '%-24s %s bytes\n' 'compiler binary' "$(wc -c < build/lithc)"
fi

"$TIME_BIN" -v sh bin/lith bench/hello.lith -o "$BUILD/hello" >"$BUILD/hello-compile.stdout" 2>"$BUILD/hello-compile.time"
report_time 'hello compile' "$BUILD/hello-compile.time"
printf '%-24s %s bytes\n' 'hello binary' "$(wc -c < "$BUILD/hello")"

"$TIME_BIN" -v "$BUILD/hello" >"$BUILD/hello.stdout" 2>"$BUILD/hello-run.time"
report_time 'hello runtime' "$BUILD/hello-run.time"
printf '%-24s %s\n' 'hello output' "$(cat "$BUILD/hello.stdout")"

printf '\nRaw GNU time reports: %s/*.time\n' "$BUILD"
