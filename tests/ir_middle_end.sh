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
# compile-time condition before LLVM lowering sees them. Mem2reg may remove the
# old stack store entirely, so assert the folded result instead of stack shape.
grep -q 'ret i32 5' "$IR"
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

DEAD_BODY="$BUILD/dead_math.ll"
sed -n '/^define i32 @dead_math/,/^}/p' "$IR" > "$DEAD_BODY"
if grep -q ' add i32 ' "$DEAD_BODY"; then
    echo 'IR DCE failed to remove dead integer computation' >&2
    exit 1
fi

LOAD_BODY="$BUILD/local_load.ll"
sed -n '/^define i32 @local_load/,/^}/p' "$IR" > "$LOAD_BODY"
if grep -q ' load i32' "$LOAD_BODY"; then
    echo 'IR load forwarding failed to remove redundant load' >&2
    exit 1
fi
grep -q 'ret i32 9' "$LOAD_BODY"

PROMOTED_BODY="$BUILD/promoted_local.ll"
sed -n '/^define i32 @promoted_local/,/^}/p' "$IR" > "$PROMOTED_BODY"
if grep -q ' alloca ' "$PROMOTED_BODY"; then
    echo 'single-block mem2reg left promotable alloca' >&2
    exit 1
fi
if grep -q ' load ' "$PROMOTED_BODY"; then
    echo 'single-block mem2reg left promotable load' >&2
    exit 1
fi
if grep -q ' store ' "$PROMOTED_BODY"; then
    echo 'single-block mem2reg left promotable store' >&2
    exit 1
fi

BRANCH_BODY="$BUILD/promoted_branch.ll"
sed -n '/^define i32 @promoted_branch/,/^}/p' "$IR" > "$BRANCH_BODY"
if grep -q ' alloca ' "$BRANCH_BODY"; then
    echo 'multi-block mem2reg left promotable alloca' >&2
    exit 1
fi
if grep -q ' load ' "$BRANCH_BODY"; then
    echo 'multi-block mem2reg left promotable load' >&2
    exit 1
fi
if grep -q ' store ' "$BRANCH_BODY"; then
    echo 'multi-block mem2reg left promotable store' >&2
    exit 1
fi
if ! grep -q ' phi i32 ' "$BRANCH_BODY"; then
    echo 'multi-block mem2reg failed to emit join phi' >&2
    exit 1
fi

# Loop/back-edge mem2reg should reserve header phi values before rewriting the
# body, then fill incoming edges after all predecessor out-values are known.
LOOP_BODY="$BUILD/promoted_loop.ll"
sed -n '/^define i32 @promoted_loop/,/^}/p' "$IR" > "$LOOP_BODY"
if grep -q ' alloca ' "$LOOP_BODY"; then
    echo 'loop mem2reg left promotable alloca' >&2
    exit 1
fi
if grep -q ' load ' "$LOOP_BODY"; then
    echo 'loop mem2reg left promotable load' >&2
    exit 1
fi
if grep -q ' store ' "$LOOP_BODY"; then
    echo 'loop mem2reg left promotable store' >&2
    exit 1
fi
LOOP_PHI_COUNT=$(grep -c ' phi i32 ' "$LOOP_BODY" || true)
if [ "$LOOP_PHI_COUNT" -lt 2 ]; then
    echo 'loop mem2reg failed to emit induction/state phis' >&2
    exit 1
fi

# This constant only becomes visible after mem2reg merges the two branch-local
# stores. SCCP must fold the post-join compare and CFG pruning must remove the
# false return path.
SCCP_BODY="$BUILD/sccp_join_constant.ll"
sed -n '/^define i32 @sccp_join_constant/,/^}/p' "$IR" > "$SCCP_BODY"
grep -q 'ret i32 11' "$SCCP_BODY"
if grep -q 'ret i32 99' "$SCCP_BODY"; then
    echo 'SCCP/CFG cleanup left dead constant false branch' >&2
    exit 1
fi
if grep -q 'icmp .* i32 7, 7' "$SCCP_BODY"; then
    echo 'SCCP failed to fold post-mem2reg constant comparison' >&2
    exit 1
fi

MAIN_BODY="$BUILD/main.ll"
sed -n '/^define i32 @main/,/^}/p' "$IR" > "$MAIN_BODY"
if grep -q 'call i32 @local_load' "$MAIN_BODY"; then
    echo 'IR CFG reachability failed to prune unreachable if.else block' >&2
    exit 1
fi
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

# Keep validation and analysis wired through the whole middle-end.
grep -q 'ir_validate_function raw' compiler/src/25_ir.lith
grep -q 'fn ir_run_optimization_pipeline' compiler/src/25_ir.lith
grep -q 'ir_validate_function current' compiler/src/25_ir.lith
grep -q 'ir_validate_function next' compiler/src/25_ir.lith
grep -q 'ir_cfg_prune_unreachable next' compiler/src/25_ir.lith
grep -q 'ir_validate_function cfg' compiler/src/25_ir.lith
grep -q 'ir_mem2reg_single_block cfg' compiler/src/25_ir.lith
grep -q 'ir_validate_function promoted' compiler/src/25_ir.lith
grep -q 'ir_optimize_function_v2 promoted' compiler/src/25_ir.lith
grep -q 'ir_validate_function cleaned' compiler/src/25_ir.lith
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
grep -q 'fn ir_cfg_prune_unreachable' compiler/src/28_ir_cfg.lith
grep -q 'fn ir_dom_compute' compiler/src/29_ir_dom.lith
grep -q 'fn ir_dom_compute_idom' compiler/src/29_ir_dom_tree.lith
grep -q 'fn ir_dom_build_tree' compiler/src/29_ir_dom_tree.lith
grep -q 'fn ir_dom_compute_frontier' compiler/src/29_ir_dom_tree.lith
grep -q 'fn ir_dom_frontier_contains' compiler/src/29_ir_dom_tree.lith
grep -q 'fn ir_ud_collect_defs' compiler/src/29_ir_use_def.lith
grep -q 'fn ir_ud_collect_uses' compiler/src/29_ir_use_def.lith
grep -q 'fn ir_validate_ssa_dominance' compiler/src/29_ir_ssa_validate.lith
grep -q 'fn ir_ssa_validate_phi_value' compiler/src/29_ir_ssa_validate.lith
grep -q 'phi incoming value does not dominate predecessor edge' compiler/src/29_ir_ssa_validate.lith
grep -q 'phi uses undefined temporary value' compiler/src/29_ir_ssa_validate.lith
grep -q 'compiler/src/29_ir_ssa_validate.lith' Makefile
grep -q 'ir_validate_ssa_dominance code' compiler/src/30_ir_mem2reg.lith
grep -q 'ir_validate_ssa_dominance multi' compiler/src/30_ir_mem2reg.lith
grep -q 'ir_sccp_optimize multi' compiler/src/30_ir_mem2reg.lith
grep -q 'ir_sccp_optimize_edges sccp' compiler/src/30_ir_mem2reg.lith
grep -q 'ir_cfg_simplify edge_sccp' compiler/src/30_ir_mem2reg.lith
grep -q 'ir_cfg_prune_unreachable simplified' compiler/src/30_ir_mem2reg.lith
grep -q 'fn ir_mem2reg_single_block' compiler/src/30_ir_mem2reg.lith
grep -q 'fn ir_mem2reg_multi_block_plan' compiler/src/31_ir_mem2reg_ssa.lith
grep -q 'fn ir_m2r_ssa_place_phis' compiler/src/31_ir_mem2reg_ssa.lith
grep -q 'fn ir_m2r_ssa_has_backedge' compiler/src/31_ir_mem2reg_ssa.lith
grep -q 'fn ir_mem2reg_multi_block' compiler/src/32_ir_mem2reg_multi.lith
grep -q 'ir_mem2reg_loop code' compiler/src/32_ir_mem2reg_multi.lith
grep -q 'fn ir_mem2reg_loop' compiler/src/33_ir_mem2reg_loop.lith
grep -q 'fn ir_m2r_loop_assign_phi_temps' compiler/src/33_ir_mem2reg_loop.lith
grep -q 'fn ir_m2r_loop_emit_phis_for_block' compiler/src/33_ir_mem2reg_loop.lith
grep -q 'loop mem2reg phi predecessor has no current value' compiler/src/33_ir_mem2reg_loop.lith
grep -q 'compiler/src/33_ir_mem2reg_loop.lith' Makefile
grep -q 'fn ir_sccp_merge_state' compiler/src/34_ir_sccp.lith
grep -q 'fn ir_sccp_phi_state' compiler/src/34_ir_sccp.lith
grep -q 'fn ir_sccp_sweep' compiler/src/34_ir_sccp.lith
grep -q 'fn ir_sccp_optimize' compiler/src/34_ir_sccp.lith
grep -q 'compiler/src/34_ir_sccp.lith' Makefile
grep -q 'fn ir_sccp_edge_phi_state' compiler/src/35_ir_sccp_edges.lith
grep -q 'ir_sccp_edge_live executable_edges, pred, block_label' compiler/src/35_ir_sccp_edges.lith
grep -q 'fn ir_sccp_optimize_edges' compiler/src/35_ir_sccp_edges.lith
grep -q 'compiler/src/35_ir_sccp_edges.lith' Makefile
grep -q 'fn ir_cfg_simplify_collect_phi_aliases' compiler/src/36_ir_cfg_simplify.lith
grep -q 'fn ir_cfg_simplify_branch_to_next' compiler/src/36_ir_cfg_simplify.lith
grep -q 'fn ir_cfg_simplify' compiler/src/36_ir_cfg_simplify.lith
grep -q 'compiler/src/36_ir_cfg_simplify.lith' Makefile

echo 'Lith IR validator + verified optimizer/CFG/mem2reg/edge-SCCP pipeline: passed'
