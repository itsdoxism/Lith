#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

import lunac_llvm as base


class BootstrapLLVMGen(base.LLVMGen):
    """Tiny recovery shim for canonical pointer-null globals.

    The historical trusted bootstrap predates Lith's explicit `null` global
    initializer. Storage v2 needs null-initialized pointer arenas, so the
    recovery compiler accepts that one already-canonical form while delegating
    everything else to the existing trusted bootstrap.
    """

    def gen_global(self, d):
        typ, name, expr = d['type'], d['name'], d['expr']
        if expr.kind == 'var' and expr.value == 'null' and (typ == 'str' or typ.startswith('ptr ')):
            self.globals[name] = base.Symbol(typ, '@' + name)
            self.global_defs.append(f'@{name} = global {self.llvm_type(typ)} null')
            return
        super().gen_global(d)


def main(argv):
    if len(argv) != 3:
        print(f'usage: {argv[0]} input.lith output.ll', file=sys.stderr)
        return 2
    try:
        src = Path(argv[1]).read_text()
        program = base.Parser(base.lex(src)).program()
        Path(argv[2]).write_text(BootstrapLLVMGen().generate(program))
        return 0
    except base.Error as exc:
        print('Lith bootstrap LLVM error:', exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
