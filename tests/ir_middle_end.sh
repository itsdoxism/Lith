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

# Optimizer v2 should remove a pure dead computation in dead_math.
DEAD_BODY="$BUILD/dead_math.ll"
sed -n '/^define i32 @dead_math/,/^}/p' "$IR" > "$DEAD_BODY"
if grep -q ' add i32 ' "$DEAD_BODY"; then
    echo 'IR DCE failed to remove dead integer computation' >&2
    exit 1
fi

# A store immediately followed by a load of the same local address should
# forward the stored value instead of lowering a redundant load.
LOAD_BODY="$BUILD/local_load.ll"
sed -n '/^define i32 @local_load/,/^}/p' "$IR" > "$LOAD_BODY"
if grep -q ' load i32' "$LOAD_BODY"; then
    echo 'IR load forwarding failed to remove redundant load' >&2
    exit 1
fi
grep -q 'ret i32 9' "$LOAD_BODY"

# CFG v1 is label-name agnostic: after the constant cbranch becomes an
# unconditional branch, the ordinary if.else block is unreachable and must be
# removed even though it is not a compiler-generated dead.* block.
MAIN_BODY="$BUILD/main.ll"
sed -n '/^define i32 @main/,/^}/p' "$IR" > "$MAIN_BODY"
if grep -q 'call i32 @local_load' "$MAIN_BODY"; then
    echo 'IR CFG reachability failed to prune unreachable if.else block' >&2
    exit 1
fi

# Source after an unconditional return is emitted behind a compiler-generated
# dead block; CFG pruning should remove the unreachable print call as well.
if grep -q 'call i32 @puts' "$IR"; then
    echo 'IR CFG pruning failed to remove unreachable print' >&2
    exit 1
fi
if grep -q '^dead\.' "$IR"; then
    echo 'IR CFG pruning left an unreachable dead block' >&2
    exit 1
fi

"$CLANG" -Wno-override-module -O2 "$IR" "$LLVM_RUNTIME" -o "$BIN"
set +e
"$BIN"
rc=$?
set -e
if [ "$rc" -ne 5 ]; then
    echo "optimized program returned $rc, expected 5" >&2
    exit 1
fi

# Keep validation wired at the raw IR boundary and after every optimization
# stage. This catches accidental pass-manager bypasses even though ordinary
# source cannot directly construct malformed internal records.
grep -q 'ir_validate_function raw' compiler/src/25_ir.lith
grep -q 'fn ir_run_optimization_pipeline' compiler/src/25_ir.lith
grep -q 'ir_validate_function current' compiler/src/25_ir.lith
grep -q 'ir_validate_function next' compiler/src/25_ir.lith
grep -q 'ir_cfg_prune_unreachable next' compiler/src/25_ir.lith
grep -q 'ir_validate_function cfg' compiler/src/25_ir.lith
grep -q 'ir_run_optimization_pipeline raw' compiler/src/25_ir.lith
grep -q 'ir_index_record_count' compiler/src/27_ir_index.lith
grep -q 'ir_index_fill' compiler/src/27_ir_index.lith
grep -q 'fn ir_cfg_collect_reachable' compiler/src/28_ir_cfg.lith
grep -q 'fn ir_cfg_collect_edges' compiler/src/28_ir_cfg.lith
grep -q 'fn ir_cfg_has_edge' compiler/src/28_ir_cfg.lith
grep -q 'fn ir_cfg_validate_phi_edges' compiler/src/28_ir_cfg.lith
grep -q 'phi contains duplicate predecessor' compiler/src/28_ir_cfg.lith
grep -q 'phi predecessor is not a CFG edge' compiler/src/28_ir_cfg.lith
grep -q 'fn ir_cfg_validate_pruned' compiler/src/28_ir_cfg.lith
grep -q 'ir_cfg_validate_pruned out' compiler/src/28_ir_cfg.lith
grep -q 'ir_cfg_has_edge edges, pred, block_label' compiler/src/28_ir_cfg.lith
grep -q 'fn ir_cfg_prune_unreachable' compiler/src/28_ir_cfg.lith
grep -q 'fn ir_dom_compute' compiler/src/29_ir_dom.lith
grep -q 'fn ir_ud_collect_defs' compiler/src/29_ir_use_def.lith
grep -q 'fn ir_ud_collect_uses' compiler/src/29_ir_use_def.lith

echo 'Lith IR validator + verified optimizer/CFG pipeline: passed'
