; Luna minimal LLVM runtime for the bootstrap compiler.
; Targeted at 64-bit POSIX libc ABIs (Linux/macOS class platforms).

@.rt.empty = private unnamed_addr constant [1 x i8] c"\00", align 1
@.rt.rb = private unnamed_addr constant [3 x i8] c"\72\62\00", align 1
@.rt.wb = private unnamed_addr constant [3 x i8] c"\77\62\00", align 1
@.rt.intfmt = private unnamed_addr constant [3 x i8] c"\25\64\00", align 1

declare ptr @malloc(i64)
declare void @free(ptr)
declare i64 @strlen(ptr)
declare ptr @memcpy(ptr, ptr, i64)
declare i32 @strcmp(ptr, ptr)
declare i32 @strncmp(ptr, ptr, i64)
declare ptr @fopen(ptr, ptr)
declare i32 @fseek(ptr, i64, i32)
declare i64 @ftell(ptr)
declare void @rewind(ptr)
declare i64 @fread(ptr, i64, i64, ptr)
declare i64 @fwrite(ptr, i64, i64, ptr)
declare i32 @fclose(ptr)
declare i32 @snprintf(ptr, i64, ptr, ...)

define internal ptr @luna_dup_range(ptr %s, i64 %n) {
entry:
  %size = add i64 %n, 1
  %out = call ptr @malloc(i64 %size)
  %null = icmp eq ptr %out, null
  br i1 %null, label %fail, label %copy
copy:
  %ignore = call ptr @memcpy(ptr %out, ptr %s, i64 %n)
  %end = getelementptr i8, ptr %out, i64 %n
  store i8 0, ptr %end
  ret ptr %out
fail:
  ret ptr null
}

define ptr @luna_read_text(ptr %path) {
entry:
  %mode = getelementptr inbounds [3 x i8], ptr @.rt.rb, i64 0, i64 0
  %f = call ptr @fopen(ptr %path, ptr %mode)
  %badf = icmp eq ptr %f, null
  br i1 %badf, label %fail, label %seek
seek:
  %sr = call i32 @fseek(ptr %f, i64 0, i32 2)
  %seekbad = icmp ne i32 %sr, 0
  br i1 %seekbad, label %closefail, label %tell
tell:
  %n = call i64 @ftell(ptr %f)
  %neg = icmp slt i64 %n, 0
  br i1 %neg, label %closefail, label %alloc
alloc:
  call void @rewind(ptr %f)
  %size = add i64 %n, 1
  %buf = call ptr @malloc(i64 %size)
  %oom = icmp eq ptr %buf, null
  br i1 %oom, label %closefail, label %read
read:
  %got = call i64 @fread(ptr %buf, i64 1, i64 %n, ptr %f)
  %cr = call i32 @fclose(ptr %f)
  %short = icmp ne i64 %got, %n
  br i1 %short, label %freefail, label %finish
finish:
  %end = getelementptr i8, ptr %buf, i64 %n
  store i8 0, ptr %end
  ret ptr %buf
freefail:
  call void @free(ptr %buf)
  ret ptr null
closefail:
  %cc = call i32 @fclose(ptr %f)
  ret ptr null
fail:
  ret ptr null
}

define i32 @luna_write_text(ptr %path, ptr %text) {
entry:
  %mode = getelementptr inbounds [3 x i8], ptr @.rt.wb, i64 0, i64 0
  %f = call ptr @fopen(ptr %path, ptr %mode)
  %bad = icmp eq ptr %f, null
  br i1 %bad, label %fail, label %write
write:
  %n = call i64 @strlen(ptr %text)
  %wrote = call i64 @fwrite(ptr %text, i64 1, i64 %n, ptr %f)
  %cr = call i32 @fclose(ptr %f)
  %a = icmp eq i64 %wrote, %n
  %b = icmp eq i32 %cr, 0
  %ok = and i1 %a, %b
  %ret = zext i1 %ok to i32
  ret i32 %ret
fail:
  ret i32 0
}

define i32 @luna_str_len(ptr %s) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %zero, label %len
len:
  %n = call i64 @strlen(ptr %s)
  %r = trunc i64 %n to i32
  ret i32 %r
zero:
  ret i32 0
}

define i32 @luna_str_at(ptr %s, i32 %index) {
entry:
  %null = icmp eq ptr %s, null
  %neg = icmp slt i32 %index, 0
  %bad0 = or i1 %null, %neg
  br i1 %bad0, label %zero, label %bounds
bounds:
  %n = call i64 @strlen(ptr %s)
  %i64 = sext i32 %index to i64
  %oob = icmp uge i64 %i64, %n
  br i1 %oob, label %zero, label %load
load:
  %p = getelementptr i8, ptr %s, i64 %i64
  %c = load i8, ptr %p
  %r = zext i8 %c to i32
  ret i32 %r
zero:
  ret i32 0
}

define ptr @luna_str_slice(ptr %s, i32 %start0, i32 %end0) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %empty, label %work
empty:
  %ep = getelementptr inbounds [1 x i8], ptr @.rt.empty, i64 0, i64 0
  %er = call ptr @luna_dup_range(ptr %ep, i64 0)
  ret ptr %er
work:
  %n64 = call i64 @strlen(ptr %s)
  %n = trunc i64 %n64 to i32
  %sneg = icmp slt i32 %start0, 0
  %start1 = select i1 %sneg, i32 0, i32 %start0
  %sgt = icmp sgt i32 %start1, %n
  %start = select i1 %sgt, i32 %n, i32 %start1
  %elt = icmp slt i32 %end0, %start
  %end1 = select i1 %elt, i32 %start, i32 %end0
  %egt = icmp sgt i32 %end1, %n
  %end = select i1 %egt, i32 %n, i32 %end1
  %start64 = sext i32 %start to i64
  %len32 = sub i32 %end, %start
  %len64 = sext i32 %len32 to i64
  %p = getelementptr i8, ptr %s, i64 %start64
  %r = call ptr @luna_dup_range(ptr %p, i64 %len64)
  ret ptr %r
}

define ptr @luna_str_concat(ptr %a0, ptr %b0) {
entry:
  %empty = getelementptr inbounds [1 x i8], ptr @.rt.empty, i64 0, i64 0
  %an = icmp eq ptr %a0, null
  %bn = icmp eq ptr %b0, null
  %a = select i1 %an, ptr %empty, ptr %a0
  %b = select i1 %bn, ptr %empty, ptr %b0
  %na = call i64 @strlen(ptr %a)
  %nb = call i64 @strlen(ptr %b)
  %sum = add i64 %na, %nb
  %size = add i64 %sum, 1
  %out = call ptr @malloc(i64 %size)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %copy
copy:
  %i1 = call ptr @memcpy(ptr %out, ptr %a, i64 %na)
  %dst = getelementptr i8, ptr %out, i64 %na
  %nb1 = add i64 %nb, 1
  %i2 = call ptr @memcpy(ptr %dst, ptr %b, i64 %nb1)
  ret ptr %out
fail:
  ret ptr null
}

define i32 @luna_str_eq(ptr %a, ptr %b) {
entry:
  %an = icmp eq ptr %a, null
  %bn = icmp eq ptr %b, null
  %either = or i1 %an, %bn
  br i1 %either, label %ptrcmp, label %cmp
ptrcmp:
  %same = icmp eq ptr %a, %b
  %r0 = zext i1 %same to i32
  ret i32 %r0
cmp:
  %c = call i32 @strcmp(ptr %a, ptr %b)
  %eq = icmp eq i32 %c, 0
  %r = zext i1 %eq to i32
  ret i32 %r
}

define i32 @luna_str_starts(ptr %s, ptr %prefix) {
entry:
  %sn = icmp eq ptr %s, null
  %pn = icmp eq ptr %prefix, null
  %bad = or i1 %sn, %pn
  br i1 %bad, label %zero, label %cmp
cmp:
  %n = call i64 @strlen(ptr %prefix)
  %c = call i32 @strncmp(ptr %s, ptr %prefix, i64 %n)
  %eq = icmp eq i32 %c, 0
  %r = zext i1 %eq to i32
  ret i32 %r
zero:
  ret i32 0
}

define ptr @luna_str_trim(ptr %s) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %empty, label %setup
empty:
  %ep = getelementptr inbounds [1 x i8], ptr @.rt.empty, i64 0, i64 0
  %er = call ptr @luna_dup_range(ptr %ep, i64 0)
  ret ptr %er
setup:
  %n = call i64 @strlen(ptr %s)
  br label %left
left:
  %li = phi i64 [0, %setup], [%linext, %leftstep]
  %ldone = icmp uge i64 %li, %n
  br i1 %ldone, label %rightsetup, label %leftchar
leftchar:
  %lp = getelementptr i8, ptr %s, i64 %li
  %lc = load i8, ptr %lp
  %sp = icmp eq i8 %lc, 32
  %tb = icmp eq i8 %lc, 9
  %cr = icmp eq i8 %lc, 13
  %nl = icmp eq i8 %lc, 10
  %w1 = or i1 %sp, %tb
  %w2 = or i1 %cr, %nl
  %ws = or i1 %w1, %w2
  br i1 %ws, label %leftstep, label %rightsetup
leftstep:
  %linext = add i64 %li, 1
  br label %left
rightsetup:
  %leftv = phi i64 [%li, %left], [%li, %leftchar]
  br label %right
right:
  %ri = phi i64 [%n, %rightsetup], [%rinext, %rightstep]
  %atleft = icmp ule i64 %ri, %leftv
  br i1 %atleft, label %finish, label %rightchar
rightchar:
  %rim1 = sub i64 %ri, 1
  %rp = getelementptr i8, ptr %s, i64 %rim1
  %rc = load i8, ptr %rp
  %rsp = icmp eq i8 %rc, 32
  %rtb = icmp eq i8 %rc, 9
  %rcr = icmp eq i8 %rc, 13
  %rnl = icmp eq i8 %rc, 10
  %rw1 = or i1 %rsp, %rtb
  %rw2 = or i1 %rcr, %rnl
  %rws = or i1 %rw1, %rw2
  br i1 %rws, label %rightstep, label %finish
rightstep:
  %rinext = sub i64 %ri, 1
  br label %right
finish:
  %end = phi i64 [%ri, %right], [%ri, %rightchar]
  %len = sub i64 %end, %leftv
  %p = getelementptr i8, ptr %s, i64 %leftv
  %out = call ptr @luna_dup_range(ptr %p, i64 %len)
  ret ptr %out
}

define ptr @luna_str_chr(i32 %code) {
entry:
  %out = call ptr @malloc(i64 2)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %ok
ok:
  %c = trunc i32 %code to i8
  store i8 %c, ptr %out
  %p1 = getelementptr i8, ptr %out, i64 1
  store i8 0, ptr %p1
  ret ptr %out
fail:
  ret ptr null
}

define ptr @luna_int_str(i32 %value) {
entry:
  %out = call ptr @malloc(i64 64)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %fmt
fmt:
  %f = getelementptr inbounds [3 x i8], ptr @.rt.intfmt, i64 0, i64 0
  %n = call i32 (ptr, i64, ptr, ...) @snprintf(ptr %out, i64 64, ptr %f, i32 %value)
  ret ptr %out
fail:
  ret ptr null
}
