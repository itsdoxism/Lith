#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
PARTS = [
    ROOT / 'compiler/bootstrap/lunac_llvm.part0.structs.luna',
    ROOT / 'compiler/bootstrap/lunac_llvm.part1.luna',
    ROOT / 'compiler/bootstrap/lunac_llvm.part2.structs.luna',
    ROOT / 'compiler/bootstrap/lunac_llvm.part3.structs.luna',
]


def replace_once(src: str, old: str, new: str, name: str) -> str:
    count = src.count(old)
    if count != 1:
        raise SystemExit(f'{name}: expected exactly one patch site, found {count}')
    return src.replace(old, new, 1)


src = ''.join(p.read_text() for p in PARTS)

helpers = r'''
fn load_match_target [int unused] str [
    if [str.eq g_kind, 'int' or str.eq g_kind, 'str'] [
        = parse_primary 0
    ]
    if [str.eq g_kind, 'id'] [
        str name = g_text
        next_tok 0
        str typ = local_type name
        if [str.eq typ, ''] [
            fail 'unknown match target'
            g_expr_type = 'int'
            = '0'
        ]
        str addr = local_addr name
        str r = new_reg 0
        str s = str.concat r, ' = load '
        s = str.concat s, storage_type typ
        s = str.concat s, ', ptr '
        s = str.concat s, addr
        emit_inst s
        g_expr_type = typ
        g_expr_addr = addr
        = r
    ]
    fail 'unsupported match target'
    g_expr_type = 'int'
    = '0'
]

fn emit_match_return [str ret] int [
    expect_id 'match'
    str target = load_match_target 0
    str target_type = g_expr_type
    expect_kind 'lb'
    skip_nl 0

    while [str.eq g_kind, 'id' and str.eq g_text, 'is'] [
        next_tok 0
        str pat = parse_expr 0
        str pat_type = g_expr_type
        str case_label = new_label 'match.case'
        str next_label = new_label 'match.next'
        str cond = ''

        if [str.eq target_type, 'str' and str.eq pat_type, 'str'] [
            str eqv = new_reg 0
            str eqs = str.concat eqv, ' = call i32 @luna_str_eq(ptr '
            eqs = str.concat eqs, target
            eqs = str.concat eqs, ', ptr '
            eqs = str.concat eqs, pat
            eqs = str.concat eqs, ')'
            emit_inst eqs
            cond = new_reg 0
            str cs = str.concat cond, ' = icmp ne i32 '
            cs = str.concat cs, eqv
            cs = str.concat cs, ', 0'
            emit_inst cs
        ]
        else [
            str left = intify target, target_type
            str right = intify pat, pat_type
            cond = new_reg 0
            str cs2 = str.concat cond, ' = icmp eq i32 '
            cs2 = str.concat cs2, left
            cs2 = str.concat cs2, ', '
            cs2 = str.concat cs2, right
            emit_inst cs2
        ]

        emit_cbranch cond, case_label, next_label
        emit_label case_label
        expect_kind 'lb'
        skip_nl 0
        str value = parse_expr 0
        str value_type = g_expr_type
        value = cast_value value, value_type, ret
        skip_nl 0
        expect_kind 'rb'
        emit_return ret, value
        emit_label next_label
        skip_nl 0
    ]

    expect_id 'else'
    expect_kind 'lb'
    skip_nl 0
    str fallback = parse_expr 0
    str fallback_type = g_expr_type
    fallback = cast_value fallback, fallback_type, ret
    skip_nl 0
    expect_kind 'rb'
    emit_return ret, fallback
    skip_nl 0
    expect_kind 'rb'
    = 0
]

fn append_print_value [str acc, str value] str [
    str r = new_reg 0
    str s = str.concat r, ' = call ptr @luna_str_concat(ptr '
    s = str.concat s, acc
    s = str.concat s, ', ptr '
    s = str.concat s, value
    s = str.concat s, ')'
    emit_inst s
    = r
]

fn print_value_for_name [str name] str [
    str typ = local_type name
    if [str.eq typ, ''] [
        fail 'unknown io.print interpolation name'
        = string_const ''
    ]
    str addr = local_addr name
    str loaded = new_reg 0
    str ls = str.concat loaded, ' = load '
    ls = str.concat ls, storage_type typ
    ls = str.concat ls, ', ptr '
    ls = str.concat ls, addr
    emit_inst ls

    if [str.eq typ, 'str'] [ = loaded ]
    if [str.eq typ, 'int' or str.eq typ, 'char' or str.eq typ, 'bool'] [
        str iv = intify loaded, typ
        str out = new_reg 0
        str call = str.concat out, ' = call ptr @luna_int_str(i32 '
        call = str.concat call, iv
        call = str.concat call, ')'
        emit_inst call
        = out
    ]
    fail 'unsupported io.print interpolation type'
    = string_const ''
]

fn emit_print_stmt [int unused] int [
    expect_id 'io'
    expect_kind 'dot'
    expect_id 'print'
    if [not str.eq g_kind, 'str'] [
        = fail 'io.print currently expects a string literal'
    ]

    str text = g_text
    next_tok 0
    str out = string_const ''
    int n = str.len text
    int i = 0
    int segment = 0

    while [i lt n] [
        if [str.at text, i eq 91] [
            if [i gt segment] [
                str literal = str.slice text, segment, i
                out = append_print_value out, string_const literal
            ]
            i = i add 1
            int start = i
            while [i lt n and str.at text, i ne 93] [ i = i add 1 ]
            if [i ge n] [ = fail 'unterminated io.print interpolation' ]
            str name = str.slice text, start, i
            str value = print_value_for_name name
            out = append_print_value out, value
            i = i add 1
            segment = i
        ]
        else [ i = i add 1 ]
    ]

    if [segment lt n] [
        str tail = str.slice text, segment, n
        out = append_print_value out, string_const tail
    ]

    str ps = str.concat 'call i32 @puts(ptr ', out
    ps = str.concat ps, ')'
    emit_inst ps
    = 0
]

'''

src = replace_once(src, 'fn parse_stmt_ir [int unused] int [\n', helpers + 'fn parse_stmt_ir [int unused] int [\n', 'helpers')

old_assign_return = '''    if [str.eq g_kind, 'assign'] [
        next_tok 0
        str rv = parse_expr 0
        str rt = g_expr_type
        rv = cast_value rv, rt, g_current_ret
        emit_return g_current_ret, rv
        = 0
    ]
'''
new_assign_return = '''    if [str.eq g_kind, 'assign'] [
        next_tok 0
        if [str.eq g_kind, 'id' and str.eq g_text, 'match'] [
            = emit_match_return g_current_ret
        ]
        str rv = parse_expr 0
        str rt = g_expr_type
        rv = cast_value rv, rt, g_current_ret
        emit_return g_current_ret, rv
        = 0
    ]
'''
src = replace_once(src, old_assign_return, new_assign_return, 'equals-return match')

old_keyword_return = '''    if [str.eq g_kind, 'id' and str.eq g_text, 'return'] [
        next_tok 0
        str rv2 = parse_expr 0
        str rt2 = g_expr_type
        rv2 = cast_value rv2, rt2, g_current_ret
        emit_return g_current_ret, rv2
        = 0
    ]
'''
new_keyword_return = '''    if [str.eq g_kind, 'id' and str.eq g_text, 'return'] [
        next_tok 0
        if [str.eq g_kind, 'id' and str.eq g_text, 'match'] [
            = emit_match_return g_current_ret
        ]
        str rv2 = parse_expr 0
        str rt2 = g_expr_type
        rv2 = cast_value rv2, rt2, g_current_ret
        emit_return g_current_ret, rv2
        = 0
    ]
'''
src = replace_once(src, old_keyword_return, new_keyword_return, 'keyword-return match')

io_site = '''    if [str.eq g_kind, 'id' and str.eq g_text, 'sys'] [
        str ignored = emit_sys_memory 'ptr int'
        = 0
    ]
'''
io_replacement = '''    if [str.eq g_kind, 'id' and str.eq g_text, 'io'] [
        = emit_print_stmt 0
    ]
''' + io_site
src = replace_once(src, io_site, io_replacement, 'io.print statement')

src = replace_once(
    src,
    "    emit_line 'declare void @free(ptr)'\n",
    "    emit_line 'declare void @free(ptr)'\n    emit_line 'declare i32 @puts(ptr)'\n",
    'puts declaration',
)

if len(sys.argv) != 2:
    raise SystemExit('usage: build_reference_parity.py OUTPUT')
Path(sys.argv[1]).write_text(src)
