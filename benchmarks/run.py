#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "benchmarks"
BUILD = BENCH / ".build"
CASES = ("empty", "loop", "array", "alloc")
RUNS = {"empty": 300, "loop": 30, "array": 30, "alloc": 30}
COMPILE_RUNS = 8

PROFILES = {
    "baseline": (["-O2"], ["-O2"]),
    "release": (["--release"], ["-O3"]),
    "native": (["--release", "--native"], ["-O3", "-march=native"]),
}


def run(cmd, **kwargs):
    return subprocess.run(cmd, cwd=ROOT, check=True, **kwargs)


def median_ms(command, repeats, quiet=True):
    samples = []
    for _ in range(repeats):
        start = time.perf_counter_ns()
        run(command, stdout=subprocess.DEVNULL if quiet else None,
            stderr=subprocess.DEVNULL if quiet else None)
        samples.append((time.perf_counter_ns() - start) / 1_000_000)
    return statistics.median(samples)


def compile_median_ms(command_factory, repeats=COMPILE_RUNS):
    samples = []
    for i in range(repeats):
        command = command_factory(i)
        start = time.perf_counter_ns()
        run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples.append((time.perf_counter_ns() - start) / 1_000_000)
    return statistics.median(samples)


def parse_args():
    parser = argparse.ArgumentParser(description="Benchmark Lith against an equivalent C baseline")
    parser.add_argument(
        "--profile",
        choices=tuple(PROFILES),
        default="baseline",
        help="backend optimization profile: baseline=-O2, release=-O3, native=-O3 -march=native",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    lith_flags, c_flags = PROFILES[args.profile]

    clang = shutil.which(os.environ.get("CLANG", "clang"))
    if not clang:
        raise SystemExit("clang is required")

    BUILD.mkdir(parents=True, exist_ok=True)
    (BENCH / "input.txt").write_text("x" * 1000)

    run(["make", "compiler"], stdout=subprocess.DEVNULL)

    rows = []
    for case in CASES:
        lith_src = BENCH / f"{case}.lith"
        c_src = BENCH / f"{case}.c"
        lith_bin = BUILD / f"{case}-lith"
        c_bin = BUILD / f"{case}-c"

        run([str(ROOT / "bin/lith"), str(lith_src), *lith_flags, "-o", str(lith_bin)])
        run([clang, *c_flags, str(c_src), "-o", str(c_bin)])

        if case != "empty":
            lith_out = subprocess.check_output([lith_bin], cwd=ROOT)
            c_out = subprocess.check_output([c_bin], cwd=ROOT)
            if lith_out != c_out:
                raise SystemExit(f"{case}: output mismatch: {lith_out!r} != {c_out!r}")

        lith_run = median_ms([str(lith_bin)], RUNS[case])
        c_run = median_ms([str(c_bin)], RUNS[case])

        lith_full_compile = compile_median_ms(
            lambda i: [
                str(ROOT / "bin/lith"), str(lith_src), *lith_flags,
                "-o", str(BUILD / f"tmp-{case}-lith-{i}"),
            ]
        )
        lith_frontend = compile_median_ms(
            lambda i: [str(ROOT / "bin/lithc"), str(lith_src), str(BUILD / f"tmp-{case}-{i}.ll")]
        )
        c_compile = compile_median_ms(
            lambda i: [clang, *c_flags, str(c_src), "-o", str(BUILD / f"tmp-{case}-c-{i}")]
        )

        rows.append((
            case,
            lith_run,
            c_run,
            lith_full_compile,
            lith_frontend,
            c_compile,
            lith_bin.stat().st_size,
            c_bin.stat().st_size,
        ))

    print(f"profile: {args.profile}")
    print("case   run Lith   run C     Lith/C   Lith compile  Lith->IR  C compile   size Lith  size C")
    print("-----  ---------  --------  -------  ------------  --------  ----------  ---------  ------")
    for row in rows:
        case, lr, cr, lfc, lfe, cc, ls, cs = row
        print(f"{case:5}  {lr:7.3f}ms  {cr:7.3f}ms  {lr/cr:6.3f}x  {lfc:9.2f}ms  {lfe:6.2f}ms  {cc:8.2f}ms  {ls:8d}B  {cs:6d}B")

    print("\nNotes:")
    print("- Runtime figures are median whole-process wall time, so startup is included.")
    print(f"- Lith and C use the same backend optimization profile: {' '.join(c_flags)}.")
    print("- Lith full compile includes lithc plus the external clang backend.")
    print("- Lith->IR measures the self-hosted Lith frontend only.")
    if args.profile == "native":
        print("- native binaries are tuned for this CPU and are not intended to be portable to older CPUs.")


if __name__ == "__main__":
    main()
