#!/usr/bin/env python3
from __future__ import annotations
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

OPS = {
    'or': 1, 'and': 2,
    'eq': 3, 'ne': 3, 'gt': 3, 'lt': 3, 'ge': 3, 'le': 3,
    'add': 4, 'sub': 4,
    'mul': 5, 'div': 5, 'mod': 5,
}
COP = {
    'or': '||', 'and': '&&',
    'eq': '==', 'ne': '!=', 'gt': '>', 'lt': '<', 'ge': '>=', 'le': '<=',
    'add': '+', 'sub': '-', 'mul': '*', 'div': '/', 'mod': '%',
}
CTYPE = {'int': 'int', 'float': 'double', 'str': 'const char *', 'bool': 'bool', 'char': 'int'}
INTRINSICS = {
    'io.read_text': 'luna_read_text',
    'io.write_text': 'luna_write_text',
    'str.len': 'luna_str_len',
    'str.at': 'luna_str_at',
    'str.slice': 'luna_str_slice',
    'str.concat': 'luna_str_concat',
    'str.eq': 'luna_str_eq',
    'str.starts': 'luna_str_starts',
    'str.trim': 'luna_str_trim',
    'str.chr': 'luna_str_chr',
    'int.str': 'luna_int_str',
}

@dataclass
class Tok:
    kind: str
    text: str
    line: int

@dataclass
class Expr:
    kind: str
    value: object = None
    a: 'Expr | None' = None
    b: 'Expr | None' = None
    args: list['Expr'] = field(default_factory=list)
    cases: list = field(default_factory=list)
    fallback: list = field(default_factory=list)

@dataclass
class Stmt:
    kind: str
    data: dict = field(default_factory=dict)

class Error(Exception):
    pass


def _read_string(src: str, i: int, line: int):
    assert src[i] == "'"
    i += 1
    out = []
    while i < len(src):
        c = src[i]
        if c == "'":
            return ''.join(out), i + 1
        if c == '\n':
            raise Error(f'line {line}: unterminated string')
        if c == '\\':
            if i + 1 >= len(src):
                raise Error(f'line {line}: unterminated escape')
            n = src[i + 1]
            escapes = {'n': '\n', 'r': '\r', 't': '\t', "'": "'", '\\': '\\'}
            out.append(escapes.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    raise Error(f'line {line}: unterminated string')


def lex(src: str):
    out = []
    i = 0
    line = 1
    while i < len(src):
        c = src[i]
        if c in ' \t\r':
            i += 1
            continue
        if c == '\n':
            out.append(Tok('nl', '', line))
            line += 1
            i += 1
            continue
        if c == '#':
            while i < len(src) and src[i] != '\n':
                i += 1
            continue
        if c == '"':
            raise Error(f'line {line}: double quoted strings are forbidden')
        if c == "'":
            text, i = _read_string(src, i, line)
            out.append(Tok('str', text, line))
            continue
        if c.isalpha() or c == '_':
            j = i + 1
            while j < len(src) and (src[j].isalnum() or src[j] == '_'):
                j += 1
            out.append(Tok('id', src[i:j], line))
            i = j
            continue
        if c.isdigit():
            j = i + 1
            kind = 'int'
            while j < len(src) and src[j].isdigit():
                j += 1
            if j < len(src) and src[j] == '.':
                kind = 'float'
                j += 1
                while j < len(src) and src[j].isdigit():
                    j += 1
            out.append(Tok(kind, src[i:j], line))
            i = j
            continue
        table = {'[': 'lb', ']': 'rb', ',': 'comma', '=': 'assign', '.': 'dot'}
        if c in table:
            out.append(Tok(table[c], c, line))
            i += 1
            continue
        raise Error(f'line {line}: unexpected character {c!r}')
    out.append(Tok('eof', '', line))
    return out


class Parser:
    DECL_TYPES = {'int', 'float', 'str', 'bool', 'char', 'arr', 'ptr'}

    def __init__(self, tokens):
        self.t = tokens
        self.i = 0
        self.match_target = False

    def cur(self):
        return self.t[self.i]

    def is_(self, kind, text=None):
        return self.cur().kind == kind and (text is None or self.cur().text == text)

    def take(self, kind, text=None):
        if not self.is_(kind, text):
            raise Error(f"line {self.cur().line}: expected {text or kind}, got {self.cur().text!r}")
        x = self.cur()
        self.i += 1
        return x

    def accept(self, kind, text=None):
        if self.is_(kind, text):
            self.i += 1
            return True
        return False

    def nl(self):
        while self.accept('nl'):
            pass

    def block(self):
        self.take('lb')
        self.nl()
        body = []
        while not self.is_('rb'):
            body.append(self.stmt())
            self.nl()
        self.take('rb')
        return body

    def starts_expr(self):
        return self.cur().kind in ('int', 'float', 'str') or self.is_('lb') or self.is_('id')

    def path(self, x):
        if x.kind == 'var':
            return x.value
        if x.kind == 'member':
            return self.path(x.a) + '.' + x.value
        raise Error(f'line {self.cur().line}: call target must be a name')

    def primary(self):
        t = self.cur()
        if t.kind in ('int', 'float', 'str'):
            self.i += 1
            return Expr(t.kind, t.text)
        if self.is_('id', 'true') or self.is_('id', 'false'):
            self.i += 1
            return Expr('bool', t.text)
        if self.accept('id', 'not'):
            return Expr('unary', 'not', a=self.primary())
        if self.is_('id', 'match'):
            self.i += 1
            self.match_target = True
            target = self.expr()
            self.match_target = False
            self.take('lb')
            self.nl()
            cases = []
            while self.accept('id', 'is'):
                pat = self.primary()
                body = self.block()
                self.nl()
                cases.append((pat, body))
            self.take('id', 'else')
            fallback = self.block()
            self.nl()
            self.take('rb')
            return Expr('match', a=target, cases=cases, fallback=fallback)
        if self.accept('lb'):
            xs = []
            self.nl()
            while not self.is_('rb'):
                xs.append(self.expr())
                if not self.accept('comma') and not self.is_('rb'):
                    raise Error(f'line {self.cur().line}: expected comma in array')
                self.nl()
            self.take('rb')
            return Expr('array', args=xs)
        if self.is_('id'):
            x = Expr('var', self.take('id').text)
            while True:
                if (not self.match_target) and self.accept('lb'):
                    idx = self.expr()
                    self.take('rb')
                    x = Expr('index', a=x, b=idx)
                elif self.accept('dot'):
                    x = Expr('member', self.take('id').text, a=x)
                else:
                    break
            if (not self.match_target) and self.starts_expr() and not (self.is_('id') and self.cur().text in OPS):
                args = []
                while self.starts_expr():
                    args.append(self.expr(6))
                    if not self.accept('comma'):
                        break
                x = Expr('call', self.path(x), args=args)
            return x
        raise Error(f'line {t.line}: expected expression')

    def expr(self, minp=0):
        left = self.primary()
        while self.is_('id') and self.cur().text in OPS and OPS[self.cur().text] >= minp:
            op = self.cur().text
            p = OPS[op]
            self.i += 1
            left = Expr('binary', op, a=left, b=self.expr(p + 1))
        return left

    def parse_type(self):
        typ = self.take('id').text
        if typ == 'ptr':
            typ += ' ' + self.take('id').text
        return typ

    def stmt(self):
        self.nl()
        if self.accept('id', 'use'):
            return Stmt('use', {'name': self.take('id').text})
        if self.accept('id', 'struct'):
            name = self.take('id').text
            self.take('lb')
            self.nl()
            fields = []
            while not self.is_('rb'):
                typ = self.parse_type()
                fields.append((typ, self.take('id').text))
                self.nl()
            self.take('rb')
            return Stmt('struct', {'name': name, 'fields': fields})
        if self.accept('id', 'fn'):
            name = self.take('id').text
            self.take('lb')
            params = []
            while not self.is_('rb'):
                typ = self.parse_type()
                params.append((typ, self.take('id').text))
                if not self.accept('comma'):
                    break
            self.take('rb')
            ret = 'int'
            if self.is_('id') and not self.is_('lb'):
                ret = self.take('id').text
            return Stmt('fn', {'name': name, 'params': params, 'ret': ret, 'body': self.block()})
        if self.accept('id', 'if'):
            self.take('lb')
            cond = self.expr()
            self.take('rb')
            yes = self.block()
            self.nl()
            no = []
            if self.accept('id', 'else'):
                no = self.block()
            return Stmt('if', {'cond': cond, 'yes': yes, 'no': no})
        if self.accept('id', 'while'):
            self.take('lb')
            cond = self.expr()
            self.take('rb')
            return Stmt('while', {'cond': cond, 'body': self.block()})
        if self.accept('id', 'loop'):
            item = self.take('id').text
            self.take('id', 'in')
            coll = self.take('id').text
            return Stmt('loop', {'item': item, 'coll': coll, 'body': self.block()})
        if self.accept('id', 'break'):
            return Stmt('break')
        if self.accept('id', 'continue'):
            return Stmt('continue')
        if self.accept('assign'):
            return Stmt('return', {'expr': self.expr()})
        if self.accept('id', 'return'):
            return Stmt('return', {'expr': self.expr()})
        if self.is_('id') and self.cur().text in self.DECL_TYPES:
            typ = self.parse_type()
            name = self.take('id').text
            self.take('assign')
            return Stmt('decl', {'type': typ, 'name': name, 'expr': self.expr()})
        target = self.expr()
        if self.accept('assign'):
            return Stmt('assign', {'target': target, 'expr': self.expr()})
        return Stmt('expr', {'expr': target})

    def program(self):
        self.nl()
        p = []
        while not self.is_('eof'):
            p.append(self.stmt())
            self.nl()
        return p


class Gen:
    def __init__(self):
        self.out = []

    def w(self, s=''):
        self.out.append(s)

    def ctype(self, t):
        if t.startswith('ptr '):
            return self.ctype(t[4:]) + ' *'
        return CTYPE.get(t, t)

    def ex(self, x):
        if x.kind in ('int', 'float'):
            return x.value
        if x.kind == 'str':
            return json.dumps(x.value)
        if x.kind == 'bool':
            return x.value
        if x.kind == 'var':
            return x.value
        if x.kind == 'member':
            return self.ex(x.a) + '.' + x.value
        if x.kind == 'index':
            return self.ex(x.a) + '[' + self.ex(x.b) + ']'
        if x.kind == 'unary':
            return '(!' + self.ex(x.a) + ')'
        if x.kind == 'binary':
            return '(' + self.ex(x.a) + ' ' + COP[x.value] + ' ' + self.ex(x.b) + ')'
        if x.kind == 'array':
            return '{' + ', '.join(self.ex(a) for a in x.args) + '}'
        if x.kind == 'call':
            name = x.value
            args = ', '.join(self.ex(a) for a in x.args)
            if name == 'sys.alloc':
                return 'malloc((' + self.ex(x.args[0]) + ') * sizeof(int))'
            if name == 'sys.realloc':
                return 'realloc(' + args + ')'
            if name == 'sys.free':
                return 'free((void *)' + self.ex(x.args[0]) + ')'
            c_name = INTRINSICS.get(name, name.replace('.', '_'))
            return c_name + '(' + args + ')'
        if x.kind == 'match':
            raise Error('match expression can only be emitted as a returned value')
        raise Error('unknown expression ' + x.kind)

    def interpolation(self, s, types):
        parts = []
        args = []
        pos = 0
        for m in re.finditer(r'\[([A-Za-z_][\w.]*)\]', s):
            parts.append(s[pos:m.start()].replace('%', '%%'))
            name = m.group(1)
            typ = types.get(name, 'int')
            parts.append('%s' if typ == 'str' else '%g' if typ == 'float' else '%d')
            args.append(name)
            pos = m.end()
        parts.append(s[pos:].replace('%', '%%'))
        return ''.join(parts), args

    def emit_return(self, x, types, ret='int'):
        if x.kind != 'match':
            self.w('return ' + self.ex(x) + ';')
            return
        tgt = self.ex(x.a)
        for i, (pat, body) in enumerate(x.cases):
            cmp = ('strcmp(' + tgt + ', ' + self.ex(pat) + ') == 0') if pat.kind == 'str' else tgt + ' == ' + self.ex(pat)
            self.w(('if' if i == 0 else 'else if') + ' (' + cmp + ') {')
            self.block(body, types.copy(), ret, True)
            self.w('}')
        self.w('else {')
        self.block(x.fallback, types.copy(), ret, True)
        self.w('}')

    def emit_decl(self, d, types, global_scope=False):
        t, n, e = d['type'], d['name'], d['expr']
        types[n] = 'str' if t == 'str' else 'float' if t == 'float' else 'int'
        prefix = '' if not global_scope else ''
        if t == 'arr':
            vals = ', '.join(self.ex(a) for a in e.args)
            self.w(f'int {n}[] = {{{vals}}};')
            self.w(f'size_t {n}_len = sizeof {n} / sizeof {n}[0];')
            types[n] = 'arr'
        elif t.startswith('ptr '):
            elem = t[4:]
            if e.kind == 'call' and e.value == 'sys.alloc':
                self.w(f'{self.ctype(elem)} *{n} = malloc(({self.ex(e.args[0])}) * sizeof *{n});')
            else:
                self.w(f'{self.ctype(elem)} *{n} = {self.ex(e)};')
            types[n] = 'ptr'
        else:
            self.w(f'{self.ctype(t)} {n} = {self.ex(e)};')

    def block(self, body, types, ret='int', value_mode=False):
        for idx, s in enumerate(body):
            k, d = s.kind, s.data
            if value_mode and idx == len(body) - 1 and k == 'expr':
                self.w('return ' + self.ex(d['expr']) + ';')
                continue
            if k == 'decl':
                self.emit_decl(d, types)
            elif k == 'assign':
                rhs = d['expr']
                lhs = self.ex(d['target'])
                if rhs.kind == 'call' and rhs.value == 'sys.realloc' and d['target'].kind == 'var':
                    self.w(f'{lhs} = realloc({self.ex(rhs.args[0])}, ({self.ex(rhs.args[1])}) * sizeof *{lhs});')
                else:
                    self.w(f'{lhs} = {self.ex(rhs)};')
            elif k == 'expr':
                e = d['expr']
                if e.kind == 'call' and e.value == 'io.print':
                    a = e.args[0]
                    if a.kind == 'str':
                        fmt, args = self.interpolation(a.value, types)
                        tail = ', ' + ', '.join(args) if args else ''
                        self.w(f'printf({json.dumps(fmt + chr(10))}{tail});')
                    else:
                        self.w('printf("%d\\n", ' + self.ex(a) + ');')
                else:
                    self.w(self.ex(e) + ';')
            elif k == 'return':
                self.emit_return(d['expr'], types, ret)
            elif k == 'if':
                self.w('if (' + self.ex(d['cond']) + ') {')
                self.block(d['yes'], types.copy(), ret)
                self.w('}')
                if d['no']:
                    self.w('else {')
                    self.block(d['no'], types.copy(), ret)
                    self.w('}')
            elif k == 'while':
                self.w('while (' + self.ex(d['cond']) + ') {')
                self.block(d['body'], types.copy(), ret)
                self.w('}')
            elif k == 'loop':
                n, c = d['item'], d['coll']
                self.w(f'for (size_t luna_i = 0; luna_i < {c}_len; ++luna_i) {{')
                self.w(f'int {n} = {c}[luna_i];')
                t = types.copy(); t[n] = 'int'
                self.block(d['body'], t, ret)
                self.w('}')
            elif k == 'break':
                self.w('break;')
            elif k == 'continue':
                self.w('continue;')

    def generate(self, program):
        self.w('#include <stdbool.h>')
        self.w('#include <stddef.h>')
        self.w('#include <stdio.h>')
        self.w('#include <stdlib.h>')
        self.w('#include <string.h>')
        self.w('#include "luna_runtime.h"')
        self.w()

        for s in program:
            if s.kind == 'struct':
                n = s.data['name']
                self.w(f'typedef struct {n} {{')
                for t, f in s.data['fields']:
                    self.w(f'    {self.ctype(t)} {f};')
                self.w(f'}} {n};')
                self.w()

        global_types = {}
        for s in program:
            if s.kind == 'decl':
                self.emit_decl(s.data, global_types, True)
        if any(s.kind == 'decl' for s in program):
            self.w()

        for s in program:
            if s.kind == 'fn':
                d = s.data
                ps = ', '.join(self.ctype(t) + ' ' + n for t, n in d['params']) or 'void'
                self.w(f'{self.ctype(d["ret"])} {d["name"]}({ps});')
        self.w()

        for s in program:
            if s.kind != 'fn':
                continue
            d = s.data
            ps = ', '.join(self.ctype(t) + ' ' + n for t, n in d['params']) or 'void'
            self.w(f'{self.ctype(d["ret"])} {d["name"]}({ps}) {{')
            types = global_types.copy()
            for t, n in d['params']:
                types[n] = 'str' if t == 'str' else 'float' if t == 'float' else 'int'
                self.w(f'(void){n};')
            self.block(d['body'], types, d['ret'])
            if d['name'] == 'main' and d['ret'] == 'int':
                self.w('return 0;')
            self.w('}')
            self.w()
        return '\n'.join(self.out)


def main(argv):
    if len(argv) != 3:
        print(f'usage: {argv[0]} input.luna output.c', file=sys.stderr)
        return 2
    try:
        src = Path(argv[1]).read_text()
        program = Parser(lex(src)).program()
        Path(argv[2]).write_text(Gen().generate(program))
        return 0
    except Error as e:
        print('Luna error:', e, file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
