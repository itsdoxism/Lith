#!/usr/bin/env python3
from __future__ import annotations

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
            i += 1; continue
        if c == '\n':
            out.append(Tok('nl', '', line)); line += 1; i += 1; continue
        if c == '#':
            while i < len(src) and src[i] != '\n': i += 1
            continue
        if c == '"':
            raise Error(f'line {line}: double quoted strings are forbidden')
        if c == "'":
            text, i = _read_string(src, i, line)
            out.append(Tok('str', text, line)); continue
        if c.isalpha() or c == '_':
            j = i + 1
            while j < len(src) and (src[j].isalnum() or src[j] == '_'): j += 1
            out.append(Tok('id', src[i:j], line)); i = j; continue
        if c.isdigit():
            j = i + 1; kind = 'int'
            while j < len(src) and src[j].isdigit(): j += 1
            if j < len(src) and src[j] == '.':
                kind = 'float'; j += 1
                while j < len(src) and src[j].isdigit(): j += 1
            out.append(Tok(kind, src[i:j], line)); i = j; continue
        table = {'[':'lb', ']':'rb', ',':'comma', '=':'assign', '.':'dot'}
        if c in table:
            out.append(Tok(table[c], c, line)); i += 1; continue
        raise Error(f'line {line}: unexpected character {c!r}')
    out.append(Tok('eof', '', line))
    return out

class Parser:
    DECL_TYPES = {'int','float','str','bool','char','arr','ptr'}
    def __init__(self, toks):
        self.t = toks; self.i = 0; self.match_target = False
    def cur(self): return self.t[self.i]
    def is_(self, kind, text=None): return self.cur().kind == kind and (text is None or self.cur().text == text)
    def take(self, kind, text=None):
        if not self.is_(kind, text):
            raise Error(f"line {self.cur().line}: expected {text or kind}, got {self.cur().text!r}")
        x = self.cur(); self.i += 1; return x
    def accept(self, kind, text=None):
        if self.is_(kind, text): self.i += 1; return True
        return False
    def nl(self):
        while self.accept('nl'): pass
    def block(self):
        self.take('lb'); self.nl(); b=[]
        while not self.is_('rb'):
            if self.is_('eof'): raise Error('unexpected eof in block')
            b.append(self.stmt()); self.nl()
        self.take('rb'); return b
    def starts_expr(self):
        return self.cur().kind in ('int','float','str') or self.is_('lb') or self.is_('id')
    def path(self, x):
        if x.kind == 'var': return x.value
        if x.kind == 'member': return self.path(x.a)+'.'+x.value
        raise Error(f'line {self.cur().line}: call target must be a name')
    def primary(self):
        t=self.cur()
        if t.kind in ('int','float','str'):
            self.i += 1; return Expr(t.kind,t.text)
        if self.is_('id','true') or self.is_('id','false'):
            self.i += 1; return Expr('bool',t.text)
        if self.accept('id','not'):
            return Expr('unary','not',a=self.primary())
        if self.is_('id','match'):
            self.i += 1; self.match_target=True; target=self.expr(); self.match_target=False
            self.take('lb'); self.nl(); cases=[]
            while self.accept('id','is'):
                pat=self.primary(); body=self.block(); self.nl(); cases.append((pat,body))
            self.take('id','else'); fb=self.block(); self.nl(); self.take('rb')
            return Expr('match',a=target,cases=cases,fallback=fb)
        if self.accept('lb'):
            xs=[]; self.nl()
            while not self.is_('rb'):
                xs.append(self.expr())
                if not self.accept('comma') and not self.is_('rb'):
                    raise Error(f'line {self.cur().line}: expected comma in array')
                self.nl()
            self.take('rb'); return Expr('array',args=xs)
        if self.is_('id'):
            x=Expr('var',self.take('id').text)
            while True:
                if (not self.match_target) and self.accept('lb'):
                    idx=self.expr(); self.take('rb'); x=Expr('index',a=x,b=idx)
                elif self.accept('dot'):
                    x=Expr('member',self.take('id').text,a=x)
                else: break
            if (not self.match_target) and self.starts_expr() and not (self.is_('id') and self.cur().text in OPS):
                args=[]
                while self.starts_expr():
                    args.append(self.expr(6))
                    if not self.accept('comma'): break
                x=Expr('call',self.path(x),args=args)
            return x
        raise Error(f'line {t.line}: expected expression')
    def expr(self,minp=0):
        left=self.primary()
        while self.is_('id') and self.cur().text in OPS and OPS[self.cur().text] >= minp:
            op=self.cur().text; p=OPS[op]; self.i += 1
            left=Expr('binary',op,a=left,b=self.expr(p+1))
        return left
    def parse_type(self):
        typ=self.take('id').text
        if typ == 'ptr': typ += ' '+self.take('id').text
        return typ
    def stmt(self):
        self.nl()
        if self.accept('id','use'): return Stmt('use',{'name':self.take('id').text})
        if self.accept('id','struct'):
            name=self.take('id').text; self.take('lb'); self.nl(); fields=[]
            while not self.is_('rb'):
                typ=self.parse_type(); fields.append((typ,self.take('id').text)); self.nl()
            self.take('rb'); return Stmt('struct',{'name':name,'fields':fields})
        if self.accept('id','fn'):
            name=self.take('id').text; self.take('lb'); params=[]
            while not self.is_('rb'):
                typ=self.parse_type(); params.append((typ,self.take('id').text))
                if not self.accept('comma'): break
            self.take('rb'); ret='int'
            if self.is_('id') and not self.is_('lb'): ret=self.take('id').text
            return Stmt('fn',{'name':name,'params':params,'ret':ret,'body':self.block()})
        if self.accept('id','if'):
            self.take('lb'); cond=self.expr(); self.take('rb'); yes=self.block(); self.nl(); no=[]
            if self.accept('id','else'): no=self.block()
            return Stmt('if',{'cond':cond,'yes':yes,'no':no})
        if self.accept('id','while'):
            self.take('lb'); cond=self.expr(); self.take('rb'); return Stmt('while',{'cond':cond,'body':self.block()})
        if self.accept('id','loop'):
            item=self.take('id').text; self.take('id','in'); coll=self.take('id').text
            return Stmt('loop',{'item':item,'coll':coll,'body':self.block()})
        if self.accept('id','break'): return Stmt('break')
        if self.accept('id','continue'): return Stmt('continue')
        if self.accept('assign'): return Stmt('return',{'expr':self.expr()})
        if self.accept('id','return'): return Stmt('return',{'expr':self.expr()})
        if self.is_('id') and self.cur().text in self.DECL_TYPES:
            typ=self.parse_type(); name=self.take('id').text; self.take('assign')
            return Stmt('decl',{'type':typ,'name':name,'expr':self.expr()})
        target=self.expr()
        if self.accept('assign'): return Stmt('assign',{'target':target,'expr':self.expr()})
        return Stmt('expr',{'expr':target})
    def program(self):
        self.nl(); p=[]
        while not self.is_('eof'):
            p.append(self.stmt()); self.nl()
        return p

@dataclass
class Symbol:
    typ: str
    addr: str
    array_len: int | None = None

@dataclass
class Value:
    typ: str
    op: str
    addr: str | None = None
    array_len: int | None = None

class FuncCtx:
    def __init__(self, gen, name, ret):
        self.g=gen; self.name=name; self.ret=ret; self.lines=[]; self.temp=0; self.label_no=0
        self.terminated=False; self.scopes=[{}]; self.loop_stack=[]
    def reg(self):
        self.temp += 1; return f'%r{self.temp}'
    def label_name(self,prefix):
        self.label_no += 1; return f'{prefix}.{self.label_no}'
    def emit(self,s):
        if self.terminated:
            self.label(self.label_name('dead'))
        self.lines.append('  '+s)
    def raw(self,s): self.lines.append(s)
    def label(self,name):
        self.lines.append(name+':'); self.terminated=False
    def br(self,label):
        self.lines.append(f'  br label %{label}'); self.terminated=True
    def cbr(self,cond,a,b):
        self.lines.append(f'  br i1 {cond}, label %{a}, label %{b}'); self.terminated=True
    def retv(self,typ,op):
        self.lines.append(f'  ret {self.g.llvm_type(typ)} {op}'); self.terminated=True
    def push(self): self.scopes.append({})
    def pop(self): self.scopes.pop()
    def add(self,name,sym): self.scopes[-1][name]=sym
    def lookup(self,name):
        for s in reversed(self.scopes):
            if name in s: return s[name]
        return self.g.globals.get(name)

class LLVMGen:
    RUNTIME_SIGS = {
        'io.read_text': ('str',['str'],'luna_read_text'),
        'io.write_text': ('int',['str','str'],'luna_write_text'),
        'str.len': ('int',['str'],'luna_str_len'),
        'str.at': ('int',['str','int'],'luna_str_at'),
        'str.slice': ('str',['str','int','int'],'luna_str_slice'),
        'str.concat': ('str',['str','str'],'luna_str_concat'),
        'str.eq': ('int',['str','str'],'luna_str_eq'),
        'str.starts': ('int',['str','str'],'luna_str_starts'),
        'str.trim': ('str',['str'],'luna_str_trim'),
        'str.chr': ('str',['int'],'luna_str_chr'),
        'int.str': ('str',['int'],'luna_int_str'),
    }
    def __init__(self):
        self.structs={}; self.struct_fields={}; self.globals={}; self.global_defs=[]; self.fn_sigs={}
        self.strings=[]; self.string_index={}; self.functions=[]
    def llvm_type(self,t):
        if t in ('int','char'): return 'i32'
        if t=='bool': return 'i1'
        if t=='float': return 'double'
        if t=='str' or t.startswith('ptr '): return 'ptr'
        if t.startswith('arr '):
            _,elem,n=t.split(' ',2); return f'[{n} x {self.llvm_type(elem)}]'
        if t in self.structs: return f'%struct.{t}'
        raise Error(f'unknown type {t!r}')
    def default_op(self,t):
        if t=='str' or t.startswith('ptr '): return 'null'
        if t=='float': return '0.0'
        if t=='bool': return '0'
        if t in self.structs: return 'zeroinitializer'
        return '0'
    def string_const(self,s):
        if s in self.string_index:
            idx=self.string_index[s]
        else:
            idx=len(self.strings); self.string_index[s]=idx
            data=s.encode('utf-8')+b'\0'; esc=''.join(f'\\{b:02X}' for b in data)
            self.strings.append((f'@.str.{idx}',len(data),esc))
        name,n,_=self.strings[idx]
        return f'getelementptr inbounds ([{n} x i8], ptr {name}, i64 0, i64 0)'
    def cast(self,ctx,v:Value,to:str):
        if v.typ==to: return v
        if to=='bool':
            if v.typ in ('int','char'):
                r=ctx.reg(); ctx.emit(f'{r} = icmp ne i32 {v.op}, 0'); return Value('bool',r)
            if v.typ=='str' or v.typ.startswith('ptr '):
                r=ctx.reg(); ctx.emit(f'{r} = icmp ne ptr {v.op}, null'); return Value('bool',r)
        if to=='int' and v.typ=='bool':
            r=ctx.reg(); ctx.emit(f'{r} = zext i1 {v.op} to i32'); return Value('int',r)
        if to=='float' and v.typ=='int':
            r=ctx.reg(); ctx.emit(f'{r} = sitofp i32 {v.op} to double'); return Value('float',r)
        if to=='int' and v.typ=='char': return Value('int',v.op,v.addr)
        if to=='char' and v.typ=='int': return Value('char',v.op,v.addr)
        if to=='str' and v.typ.startswith('ptr char'): return Value('str',v.op,v.addr)
        if to.startswith('ptr ') and (v.typ=='str' or v.typ.startswith('ptr ')): return Value(to,v.op,v.addr)
        raise Error(f'cannot convert {v.typ} to {to}')
    def load_symbol(self,ctx,sym:Symbol):
        if sym.typ.startswith('arr '): return Value(sym.typ,sym.addr,sym.addr,sym.array_len)
        if sym.typ in self.structs: return Value(sym.typ,sym.addr,sym.addr)
        r=ctx.reg(); ctx.emit(f'{r} = load {self.llvm_type(sym.typ)}, ptr {sym.addr}')
        return Value(sym.typ,r,sym.addr,sym.array_len)
    def lvalue(self,ctx,x:Expr):
        if x.kind=='var':
            sym=ctx.lookup(x.value)
            if not sym: raise Error(f'unknown variable {x.value}')
            return self.load_symbol(ctx,sym)
        if x.kind=='index':
            base=self.expr(ctx,x.a); idx=self.cast(ctx,self.expr(ctx,x.b),'int')
            if base.typ.startswith('ptr '):
                elem=base.typ[4:]; et=self.llvm_type(elem); r=ctx.reg()
                ctx.emit(f'{r} = getelementptr inbounds {et}, ptr {base.op}, i32 {idx.op}')
                if elem in self.structs: return Value(elem,r,r)
                rr=ctx.reg(); ctx.emit(f'{rr} = load {et}, ptr {r}'); return Value(elem,rr,r)
            if base.typ.startswith('arr '):
                _,elem,n=base.typ.split(' ',2); at=self.llvm_type(base.typ); r=ctx.reg()
                ctx.emit(f'{r} = getelementptr inbounds {at}, ptr {base.addr}, i32 0, i32 {idx.op}')
                et=self.llvm_type(elem); rr=ctx.reg(); ctx.emit(f'{rr} = load {et}, ptr {r}')
                return Value(elem,rr,r)
            raise Error(f'cannot index {base.typ}')
        if x.kind=='member':
            base=self.lvalue(ctx,x.a)
            st=base.typ
            if st.startswith('ptr '): st=st[4:]
            if st not in self.struct_fields: raise Error(f'{st} has no fields')
            fields=self.struct_fields[st]
            if x.value not in fields: raise Error(f'{st} has no field {x.value}')
            idx,ft=fields[x.value]; r=ctx.reg()
            ctx.emit(f'{r} = getelementptr inbounds %struct.{st}, ptr {base.addr}, i32 0, i32 {idx}')
            if ft in self.structs: return Value(ft,r,r)
            rr=ctx.reg(); ctx.emit(f'{rr} = load {self.llvm_type(ft)}, ptr {r}')
            return Value(ft,rr,r)
        raise Error('expression is not assignable')
    def expr(self,ctx,x:Expr,expected=None):
        if x.kind=='int': return Value('int',x.value)
        if x.kind=='float': return Value('float',x.value)
        if x.kind=='str': return Value('str',self.string_const(x.value))
        if x.kind=='bool': return Value('bool','1' if x.value=='true' else '0')
        if x.kind in ('var','index','member'): return self.lvalue(ctx,x)
        if x.kind=='unary':
            v=self.cast(ctx,self.expr(ctx,x.a),'bool'); r=ctx.reg(); ctx.emit(f'{r} = xor i1 {v.op}, true'); return Value('bool',r)
        if x.kind=='binary':
            a=self.expr(ctx,x.a); b=self.expr(ctx,x.b); op=x.value
            if op in ('and','or'):
                a=self.cast(ctx,a,'bool'); b=self.cast(ctx,b,'bool'); r=ctx.reg(); inst='and' if op=='and' else 'or'
                ctx.emit(f'{r} = {inst} i1 {a.op}, {b.op}'); return Value('bool',r)
            if op in ('eq','ne','gt','lt','ge','le'):
                if a.typ=='str' and b.typ=='str' and op in ('eq','ne'):
                    r0=ctx.reg(); ctx.emit(f'{r0} = call i32 @luna_str_eq(ptr {a.op}, ptr {b.op})')
                    r=ctx.reg(); pred='ne' if op=='eq' else 'eq'; ctx.emit(f'{r} = icmp {pred} i32 {r0}, 0'); return Value('bool',r)
                if a.typ=='float' or b.typ=='float':
                    a=self.cast(ctx,a,'float'); b=self.cast(ctx,b,'float'); pred={'eq':'oeq','ne':'one','gt':'ogt','lt':'olt','ge':'oge','le':'ole'}[op]
                    r=ctx.reg(); ctx.emit(f'{r} = fcmp {pred} double {a.op}, {b.op}'); return Value('bool',r)
                if a.typ=='bool': a=self.cast(ctx,a,'int')
                if b.typ=='bool': b=self.cast(ctx,b,'int')
                pred={'eq':'eq','ne':'ne','gt':'sgt','lt':'slt','ge':'sge','le':'sle'}[op]
                r=ctx.reg(); ctx.emit(f'{r} = icmp {pred} i32 {a.op}, {b.op}'); return Value('bool',r)
            if a.typ=='float' or b.typ=='float':
                a=self.cast(ctx,a,'float'); b=self.cast(ctx,b,'float'); inst={'add':'fadd','sub':'fsub','mul':'fmul','div':'fdiv'}.get(op)
                if not inst: raise Error('mod is not defined for float')
                r=ctx.reg(); ctx.emit(f'{r} = {inst} double {a.op}, {b.op}'); return Value('float',r)
            if a.typ=='bool': a=self.cast(ctx,a,'int')
            if b.typ=='bool': b=self.cast(ctx,b,'int')
            inst={'add':'add','sub':'sub','mul':'mul','div':'sdiv','mod':'srem'}[op]
            r=ctx.reg(); ctx.emit(f'{r} = {inst} i32 {a.op}, {b.op}'); return Value('int',r)
        if x.kind=='call': return self.call(ctx,x,expected)
        if x.kind=='array': raise Error('array literal is only valid in an arr declaration')
        if x.kind=='match': raise Error('match expression is only valid as a returned value')
        raise Error(f'unsupported expression {x.kind}')
    def sizeof_ptr_count(self,ctx,elem,count:Value):
        count=self.cast(ctx,count,'int'); p=ctx.reg(); ctx.emit(f'{p} = getelementptr {self.llvm_type(elem)}, ptr null, i32 {count.op}')
        n=ctx.reg(); ctx.emit(f'{n} = ptrtoint ptr {p} to i64'); return n
    def call(self,ctx,x:Expr,expected=None):
        name=x.value
        if name=='sys.alloc':
            if not expected or not expected.startswith('ptr '): raise Error('sys.alloc requires pointer target type')
            elem=expected[4:]; count=self.expr(ctx,x.args[0]); n=self.sizeof_ptr_count(ctx,elem,count); r=ctx.reg(); ctx.emit(f'{r} = call ptr @malloc(i64 {n})'); return Value(expected,r)
        if name=='sys.realloc':
            if not expected or not expected.startswith('ptr '): raise Error('sys.realloc requires pointer target type')
            old=self.cast(ctx,self.expr(ctx,x.args[0]),expected); count=self.expr(ctx,x.args[1]); n=self.sizeof_ptr_count(ctx,expected[4:],count)
            r=ctx.reg(); ctx.emit(f'{r} = call ptr @realloc(ptr {old.op}, i64 {n})'); return Value(expected,r)
        if name=='sys.free':
            v=self.expr(ctx,x.args[0]); ctx.emit(f'call void @free(ptr {v.op})'); return Value('int','0')
        if name=='io.print':
            self.emit_print(ctx,x.args[0]); return Value('int','0')
        if name in self.RUNTIME_SIGS:
            ret,pts,cname=self.RUNTIME_SIGS[name]
            vals=[]
            if len(pts)!=len(x.args): raise Error(f'{name} expects {len(pts)} args')
            for a,t in zip(x.args,pts): vals.append(self.cast(ctx,self.expr(ctx,a),t))
            args=', '.join(f'{self.llvm_type(t)} {v.op}' for t,v in zip(pts,vals))
            r=ctx.reg(); ctx.emit(f'{r} = call {self.llvm_type(ret)} @{cname}({args})'); return Value(ret,r)
        if name not in self.fn_sigs: raise Error(f'unknown function {name}')
        ret,params=self.fn_sigs[name]
        if len(params)!=len(x.args): raise Error(f'{name} expects {len(params)} args, got {len(x.args)}')
        vals=[]
        for a,(t,_) in zip(x.args,params): vals.append(self.cast(ctx,self.expr(ctx,a),t))
        args=', '.join(f'{self.llvm_type(t)} {v.op}' for (t,_),v in zip(params,vals))
        r=ctx.reg(); ctx.emit(f'{r} = call {self.llvm_type(ret)} @{name}({args})'); return Value(ret,r)
    def emit_print(self,ctx,arg:Expr):
        if arg.kind=='str' and re.search(r'\[([A-Za-z_][\w.]*)\]',arg.value):
            fmt=[]; vals=[]; pos=0
            for m in re.finditer(r'\[([A-Za-z_][\w.]*)\]',arg.value):
                fmt.append(arg.value[pos:m.start()].replace('%','%%')); path=m.group(1)
                parts=path.split('.'); e=Expr('var',parts[0])
                for p in parts[1:]: e=Expr('member',p,a=e)
                v=self.expr(ctx,e); vals.append(v)
                fmt.append('%s' if v.typ=='str' else '%g' if v.typ=='float' else '%d'); pos=m.end()
            fmt.append(arg.value[pos:].replace('%','%%')); fmt=''.join(fmt)+'\n'; f=self.string_const(fmt)
            args=[f'ptr {f}']
            for v in vals:
                if v.typ=='bool': v=self.cast(ctx,v,'int')
                args.append(f'{self.llvm_type(v.typ)} {v.op}')
            r=ctx.reg(); ctx.emit(f'{r} = call i32 (ptr, ...) @printf('+', '.join(args)+')'); return
        v=self.expr(ctx,arg)
        if v.typ=='str': fmt=self.string_const('%s\n'); args=f'ptr {fmt}, ptr {v.op}'
        elif v.typ=='float': fmt=self.string_const('%g\n'); args=f'ptr {fmt}, double {v.op}'
        else:
            if v.typ=='bool': v=self.cast(ctx,v,'int')
            fmt=self.string_const('%d\n'); args=f'ptr {fmt}, i32 {v.op}'
        r=ctx.reg(); ctx.emit(f'{r} = call i32 (ptr, ...) @printf({args})')
    def emit_decl(self,ctx,d):
        t,n,e=d['type'],d['name'],d['expr']
        if t=='arr':
            if e.kind!='array': raise Error('arr declaration requires array literal')
            elem='int' if not e.args else self.expr(ctx,e.args[0]).typ
            count=len(e.args); typ=f'arr {elem} {count}'; at=self.llvm_type(typ); slot=ctx.reg(); ctx.emit(f'{slot} = alloca {at}')
            ctx.add(n,Symbol(typ,slot,count))
            for i,a in enumerate(e.args):
                v=self.cast(ctx,self.expr(ctx,a),elem); p=ctx.reg(); ctx.emit(f'{p} = getelementptr inbounds {at}, ptr {slot}, i32 0, i32 {i}'); ctx.emit(f'store {self.llvm_type(elem)} {v.op}, ptr {p}')
            return
        slot=ctx.reg(); ctx.emit(f'{slot} = alloca {self.llvm_type(t)}'); ctx.add(n,Symbol(t,slot))
        v=self.cast(ctx,self.expr(ctx,e,t),t); ctx.emit(f'store {self.llvm_type(t)} {v.op}, ptr {slot}')
    def emit_return_expr(self,ctx,x:Expr,ret):
        if x.kind!='match':
            v=self.cast(ctx,self.expr(ctx,x,ret),ret); ctx.retv(ret,v.op); return
        target=self.expr(ctx,x.a)
        for pat,body in x.cases:
            case=ctx.label_name('match.case'); nxt=ctx.label_name('match.next'); pv=self.expr(ctx,pat)
            if target.typ=='str' and pv.typ=='str':
                r0=ctx.reg(); ctx.emit(f'{r0} = call i32 @luna_str_eq(ptr {target.op}, ptr {pv.op})'); cond=ctx.reg(); ctx.emit(f'{cond} = icmp ne i32 {r0}, 0')
            else:
                tv=self.cast(ctx,target,pv.typ if pv.typ=='float' else target.typ); pv=self.cast(ctx,pv,tv.typ); cond=ctx.reg(); ctx.emit(f'{cond} = icmp eq {self.llvm_type(tv.typ)} {tv.op}, {pv.op}')
            ctx.cbr(cond,case,nxt); ctx.label(case); self.emit_value_block(ctx,body,ret)
            if not ctx.terminated: ctx.retv(ret,self.default_op(ret))
            ctx.label(nxt)
        self.emit_value_block(ctx,x.fallback,ret)
        if not ctx.terminated: ctx.retv(ret,self.default_op(ret))
    def emit_value_block(self,ctx,body,ret):
        ctx.push()
        for i,s in enumerate(body):
            if i==len(body)-1 and s.kind=='expr':
                v=self.cast(ctx,self.expr(ctx,s.data['expr'],ret),ret); ctx.retv(ret,v.op)
            else: self.emit_stmt(ctx,s,ret)
        ctx.pop()
    def emit_stmt(self,ctx,s,ret):
        k,d=s.kind,s.data
        if k=='decl': self.emit_decl(ctx,d); return
        if k=='assign':
            lv=self.lvalue(ctx,d['target']); rv=self.cast(ctx,self.expr(ctx,d['expr'],lv.typ),lv.typ)
            if not lv.addr: raise Error('assignment target has no address')
            ctx.emit(f'store {self.llvm_type(lv.typ)} {rv.op}, ptr {lv.addr}'); return
        if k=='expr': self.expr(ctx,d['expr']); return
        if k=='return': self.emit_return_expr(ctx,d['expr'],ret); return
        if k=='break':
            if not ctx.loop_stack: raise Error('break outside loop')
            ctx.br(ctx.loop_stack[-1][0]); return
        if k=='continue':
            if not ctx.loop_stack: raise Error('continue outside loop')
            ctx.br(ctx.loop_stack[-1][1]); return
        if k=='if':
            cond=self.cast(ctx,self.expr(ctx,d['cond']),'bool'); yes=ctx.label_name('if.then'); no=ctx.label_name('if.else'); end=ctx.label_name('if.end')
            ctx.cbr(cond.op,yes,no if d['no'] else end)
            ctx.label(yes); ctx.push()
            for st in d['yes']: self.emit_stmt(ctx,st,ret)
            ctx.pop(); yterm=ctx.terminated
            if not yterm: ctx.br(end)
            nterm=False
            if d['no']:
                ctx.label(no); ctx.push()
                for st in d['no']: self.emit_stmt(ctx,st,ret)
                ctx.pop(); nterm=ctx.terminated
                if not nterm: ctx.br(end)
            ctx.label(end)
            if d['no'] and yterm and nterm: ctx.emit('unreachable')
            return
        if k=='while':
            condl=ctx.label_name('while.cond'); body=ctx.label_name('while.body'); end=ctx.label_name('while.end')
            if not ctx.terminated: ctx.br(condl)
            ctx.label(condl); cond=self.cast(ctx,self.expr(ctx,d['cond']),'bool'); ctx.cbr(cond.op,body,end)
            ctx.label(body); ctx.loop_stack.append((end,condl)); ctx.push()
            for st in d['body']: self.emit_stmt(ctx,st,ret)
            ctx.pop(); ctx.loop_stack.pop()
            if not ctx.terminated: ctx.br(condl)
            ctx.label(end); return
        if k=='loop':
            sym=ctx.lookup(d['coll'])
            if not sym or not sym.typ.startswith('arr '): raise Error('loop currently requires arr collection')
            _,elem,n=sym.typ.split(' ',2); n=int(n)
            idxslot=ctx.reg(); ctx.emit(f'{idxslot} = alloca i32'); ctx.emit(f'store i32 0, ptr {idxslot}')
            condl=ctx.label_name('loop.cond'); body=ctx.label_name('loop.body'); step=ctx.label_name('loop.step'); end=ctx.label_name('loop.end'); ctx.br(condl)
            ctx.label(condl); iv=ctx.reg(); ctx.emit(f'{iv} = load i32, ptr {idxslot}'); c=ctx.reg(); ctx.emit(f'{c} = icmp slt i32 {iv}, {n}'); ctx.cbr(c,body,end)
            ctx.label(body); at=self.llvm_type(sym.typ); p=ctx.reg(); ctx.emit(f'{p} = getelementptr inbounds {at}, ptr {sym.addr}, i32 0, i32 {iv}'); vv=ctx.reg(); ctx.emit(f'{vv} = load {self.llvm_type(elem)}, ptr {p}')
            ctx.push(); itemslot=ctx.reg(); ctx.emit(f'{itemslot} = alloca {self.llvm_type(elem)}'); ctx.emit(f'store {self.llvm_type(elem)} {vv}, ptr {itemslot}'); ctx.add(d['item'],Symbol(elem,itemslot)); ctx.loop_stack.append((end,step))
            for st in d['body']: self.emit_stmt(ctx,st,ret)
            ctx.loop_stack.pop(); ctx.pop()
            if not ctx.terminated: ctx.br(step)
            ctx.label(step); old=ctx.reg(); ctx.emit(f'{old} = load i32, ptr {idxslot}'); nxt=ctx.reg(); ctx.emit(f'{nxt} = add i32 {old}, 1'); ctx.emit(f'store i32 {nxt}, ptr {idxslot}'); ctx.br(condl)
            ctx.label(end); return
        raise Error(f'unsupported statement {k}')
    def gen_function(self,d):
        name,params,ret=d['name'],d['params'],d['ret']; ctx=FuncCtx(self,name,ret)
        args=', '.join(f'{self.llvm_type(t)} %arg.{n}' for t,n in params)
        ctx.raw(f'define {self.llvm_type(ret)} @{name}({args}) {{'); ctx.label('entry')
        for t,n in params:
            slot=ctx.reg(); ctx.emit(f'{slot} = alloca {self.llvm_type(t)}'); ctx.emit(f'store {self.llvm_type(t)} %arg.{n}, ptr {slot}'); ctx.add(n,Symbol(t,slot))
        for s in d['body']: self.emit_stmt(ctx,s,ret)
        if not ctx.terminated: ctx.retv(ret,self.default_op(ret))
        ctx.raw('}')
        self.functions.append('\n'.join(ctx.lines))
    def gen_global(self,d):
        t,n,e=d['type'],d['name'],d['expr']
        if t=='arr': raise Error('global arrays are not implemented yet')
        if e.kind=='int': init=e.value
        elif e.kind=='float': init=e.value
        elif e.kind=='bool': init='1' if e.value=='true' else '0'
        elif e.kind=='str': init=self.string_const(e.value)
        else: raise Error(f'global {n} needs a constant initializer')
        self.globals[n]=Symbol(t,'@'+n); self.global_defs.append(f'@{n} = global {self.llvm_type(t)} {init}')
    def generate(self,program):
        for s in program:
            if s.kind=='struct':
                n=s.data['name']; self.structs[n]=s.data['fields']; self.struct_fields[n]={f:(i,t) for i,(t,f) in enumerate(s.data['fields'])}
            elif s.kind=='fn': self.fn_sigs[s.data['name']] = (s.data['ret'],s.data['params'])
        for s in program:
            if s.kind=='decl': self.gen_global(s.data)
        for s in program:
            if s.kind=='fn': self.gen_function(s.data)
        out=['; Luna LLVM backend','source_filename = "luna"','']
        for n,fields in self.structs.items(): out.append(f'%struct.{n} = type {{ '+', '.join(self.llvm_type(t) for t,_ in fields)+' }')
        if self.structs: out.append('')
        for name,n,esc in self.strings: out.append(f'{name} = private unnamed_addr constant [{n} x i8] c"{esc}", align 1')
        if self.strings: out.append('')
        out.extend(self.global_defs)
        if self.global_defs: out.append('')
        out += [
            'declare ptr @malloc(i64)', 'declare ptr @realloc(ptr, i64)', 'declare void @free(ptr)',
            'declare i32 @printf(ptr, ...)',
            'declare ptr @luna_read_text(ptr)', 'declare i32 @luna_write_text(ptr, ptr)',
            'declare i32 @luna_str_len(ptr)', 'declare i32 @luna_str_at(ptr, i32)',
            'declare ptr @luna_str_slice(ptr, i32, i32)', 'declare ptr @luna_str_concat(ptr, ptr)',
            'declare i32 @luna_str_eq(ptr, ptr)', 'declare i32 @luna_str_starts(ptr, ptr)',
            'declare ptr @luna_str_trim(ptr)', 'declare ptr @luna_str_chr(i32)', 'declare ptr @luna_int_str(i32)', '',
        ]
        out.extend(self.functions)
        return '\n'.join(out)+'\n'

def main(argv):
    if len(argv)!=3:
        print(f'usage: {argv[0]} input.luna output.ll',file=sys.stderr); return 2
    try:
        src=Path(argv[1]).read_text(); p=Parser(lex(src)).program(); Path(argv[2]).write_text(LLVMGen().generate(p)); return 0
    except Error as e:
        print('Luna LLVM error:',e,file=sys.stderr); return 1
if __name__=='__main__': raise SystemExit(main(sys.argv))
