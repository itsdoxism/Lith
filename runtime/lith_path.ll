; Lith path utility runtime.
; Platform-neutral lexical helpers. Both '/' and '\\' are accepted as separators;
; normalized output uses '/'. No filesystem access is performed here.

declare ptr @malloc(i64)
declare void @free(ptr)
declare i64 @strlen(ptr)
declare ptr @memcpy(ptr, ptr, i64)

@.path.empty = private unnamed_addr constant [1 x i8] c"\00", align 1


define internal i1 @lith_path_is_sep(i8 %c) {
entry:
  %slash = icmp eq i8 %c, 47
  %back = icmp eq i8 %c, 92
  %r = or i1 %slash, %back
  ret i1 %r
}


define internal ptr @lith_path_dup_range(ptr %s, i64 %start, i64 %n) {
entry:
  %size = add i64 %n, 1
  %out = call ptr @malloc(i64 %size)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %copy
copy:
  %src = getelementptr i8, ptr %s, i64 %start
  %ignored = call ptr @memcpy(ptr %out, ptr %src, i64 %n)
  %end = getelementptr i8, ptr %out, i64 %n
  store i8 0, ptr %end
  ret ptr %out
fail:
  ret ptr null
}


define ptr @path.join(ptr %a, ptr %b) {
entry:
  %an = icmp eq ptr %a, null
  %bn = icmp eq ptr %b, null
  br i1 %an, label %onlyb, label %havea
onlyb:
  br i1 %bn, label %empty, label %copyb
copyb:
  %nb0 = call i64 @strlen(ptr %b)
  %rb = call ptr @lith_path_dup_range(ptr %b, i64 0, i64 %nb0)
  ret ptr %rb
empty:
  %e = getelementptr inbounds [1 x i8], ptr @.path.empty, i64 0, i64 0
  %re = call ptr @lith_path_dup_range(ptr %e, i64 0, i64 0)
  ret ptr %re
havea:
  br i1 %bn, label %copya, label %work
copya:
  %na0 = call i64 @strlen(ptr %a)
  %ra = call ptr @lith_path_dup_range(ptr %a, i64 0, i64 %na0)
  ret ptr %ra
work:
  %na = call i64 @strlen(ptr %a)
  %nb = call i64 @strlen(ptr %b)
  %az = icmp eq i64 %na, 0
  br i1 %az, label %copyb2, label %bcheck
copyb2:
  %rb2 = call ptr @lith_path_dup_range(ptr %b, i64 0, i64 %nb)
  ret ptr %rb2
bcheck:
  %bz = icmp eq i64 %nb, 0
  br i1 %bz, label %copya2, label %seps
copya2:
  %ra2 = call ptr @lith_path_dup_range(ptr %a, i64 0, i64 %na)
  ret ptr %ra2
seps:
  %ai = sub i64 %na, 1
  %ap = getelementptr i8, ptr %a, i64 %ai
  %ac = load i8, ptr %ap
  %asep = call i1 @lith_path_is_sep(i8 %ac)
  %bc = load i8, ptr %b
  %bsep = call i1 @lith_path_is_sep(i8 %bc)
  br i1 %asep, label %aends, label %ano
ano:
  br i1 %bsep, label %noslash, label %addslash
aends:
  br i1 %bsep, label %skipb, label %noslash
skipb:
  %nbm1 = sub i64 %nb, 1
  %total0 = add i64 %na, %nbm1
  %size0 = add i64 %total0, 1
  %out0 = call ptr @malloc(i64 %size0)
  %bad0 = icmp eq ptr %out0, null
  br i1 %bad0, label %fail, label %copy0
copy0:
  %i0a = call ptr @memcpy(ptr %out0, ptr %a, i64 %na)
  %dst0 = getelementptr i8, ptr %out0, i64 %na
  %bsrc = getelementptr i8, ptr %b, i64 1
  %i0b = call ptr @memcpy(ptr %dst0, ptr %bsrc, i64 %nbm1)
  %end0 = getelementptr i8, ptr %out0, i64 %total0
  store i8 0, ptr %end0
  ret ptr %out0
noslash:
  %total1 = add i64 %na, %nb
  %size1 = add i64 %total1, 1
  %out1 = call ptr @malloc(i64 %size1)
  %bad1 = icmp eq ptr %out1, null
  br i1 %bad1, label %fail, label %copy1
copy1:
  %i1a = call ptr @memcpy(ptr %out1, ptr %a, i64 %na)
  %dst1 = getelementptr i8, ptr %out1, i64 %na
  %i1b = call ptr @memcpy(ptr %dst1, ptr %b, i64 %nb)
  %end1 = getelementptr i8, ptr %out1, i64 %total1
  store i8 0, ptr %end1
  ret ptr %out1
addslash:
  %ab = add i64 %na, %nb
  %total2 = add i64 %ab, 1
  %size2 = add i64 %total2, 1
  %out2 = call ptr @malloc(i64 %size2)
  %bad2 = icmp eq ptr %out2, null
  br i1 %bad2, label %fail, label %copy2
copy2:
  %i2a = call ptr @memcpy(ptr %out2, ptr %a, i64 %na)
  %slashp = getelementptr i8, ptr %out2, i64 %na
  store i8 47, ptr %slashp
  %off = add i64 %na, 1
  %dst2 = getelementptr i8, ptr %out2, i64 %off
  %i2b = call ptr @memcpy(ptr %dst2, ptr %b, i64 %nb)
  %end2 = getelementptr i8, ptr %out2, i64 %total2
  store i8 0, ptr %end2
  ret ptr %out2
fail:
  ret ptr null
}


define ptr @path.basename(ptr %s) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %empty, label %work
empty:
  %e = getelementptr inbounds [1 x i8], ptr @.path.empty, i64 0, i64 0
  %r0 = call ptr @lith_path_dup_range(ptr %e, i64 0, i64 0)
  ret ptr %r0
work:
  %n = call i64 @strlen(ptr %s)
  br label %trim
trim:
  %end = phi i64 [%n, %work], [%prev, %trimstep]
  %done = icmp eq i64 %end, 0
  br i1 %done, label %allsep, label %trimcheck
trimcheck:
  %prev = sub i64 %end, 1
  %p = getelementptr i8, ptr %s, i64 %prev
  %c = load i8, ptr %p
  %sep = call i1 @lith_path_is_sep(i8 %c)
  br i1 %sep, label %trimstep, label %scan
trimstep:
  br label %trim
allsep:
  %rsep = call ptr @lith_path_dup_range(ptr %s, i64 0, i64 1)
  ret ptr %rsep
scan:
  br label %loop
loop:
  %i = phi i64 [%end, %scan], [%im1, %step]
  %at0 = icmp eq i64 %i, 0
  br i1 %at0, label %whole, label %check
check:
  %im1 = sub i64 %i, 1
  %q = getelementptr i8, ptr %s, i64 %im1
  %ch = load i8, ptr %q
  %is = call i1 @lith_path_is_sep(i8 %ch)
  br i1 %is, label %found, label %step
step:
  br label %loop
found:
  %start = add i64 %im1, 1
  %len = sub i64 %end, %start
  %r = call ptr @lith_path_dup_range(ptr %s, i64 %start, i64 %len)
  ret ptr %r
whole:
  %rw = call ptr @lith_path_dup_range(ptr %s, i64 0, i64 %end)
  ret ptr %rw
}


define ptr @path.dirname(ptr %s) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %empty, label %work
empty:
  %e = getelementptr inbounds [1 x i8], ptr @.path.empty, i64 0, i64 0
  %r0 = call ptr @lith_path_dup_range(ptr %e, i64 0, i64 0)
  ret ptr %r0
work:
  %n = call i64 @strlen(ptr %s)
  br label %trim
trim:
  %end = phi i64 [%n, %work], [%prev, %trimstep]
  %at0 = icmp eq i64 %end, 0
  br i1 %at0, label %empty, label %trimcheck
trimcheck:
  %prev = sub i64 %end, 1
  %p = getelementptr i8, ptr %s, i64 %prev
  %c = load i8, ptr %p
  %sep = call i1 @lith_path_is_sep(i8 %c)
  br i1 %sep, label %trimstep, label %scan
trimstep:
  br label %trim
scan:
  br label %loop
loop:
  %i = phi i64 [%end, %scan], [%im1, %step]
  %z = icmp eq i64 %i, 0
  br i1 %z, label %empty, label %check
check:
  %im1 = sub i64 %i, 1
  %q = getelementptr i8, ptr %s, i64 %im1
  %ch = load i8, ptr %q
  %is = call i1 @lith_path_is_sep(i8 %ch)
  br i1 %is, label %found, label %step
step:
  br label %loop
found:
  %root = icmp eq i64 %im1, 0
  %len = select i1 %root, i64 1, i64 %im1
  %r = call ptr @lith_path_dup_range(ptr %s, i64 0, i64 %len)
  ret ptr %r
}


define ptr @path.ext(ptr %s) {
entry:
  %base = call ptr @path.basename(ptr %s)
  %bad = icmp eq ptr %base, null
  br i1 %bad, label %fail, label %work
work:
  %n = call i64 @strlen(ptr %base)
  br label %loop
loop:
  %i = phi i64 [%n, %work], [%im1, %step]
  %z = icmp eq i64 %i, 0
  br i1 %z, label %none, label %check
check:
  %im1 = sub i64 %i, 1
  %p = getelementptr i8, ptr %base, i64 %im1
  %c = load i8, ptr %p
  %dot = icmp eq i8 %c, 46
  br i1 %dot, label %found, label %step
step:
  br label %loop
found:
  %leading = icmp eq i64 %im1, 0
  br i1 %leading, label %none, label %copy
copy:
  %len = sub i64 %n, %im1
  %r = call ptr @lith_path_dup_range(ptr %base, i64 %im1, i64 %len)
  call void @free(ptr %base)
  ret ptr %r
none:
  call void @free(ptr %base)
  %e = getelementptr inbounds [1 x i8], ptr @.path.empty, i64 0, i64 0
  %rn = call ptr @lith_path_dup_range(ptr %e, i64 0, i64 0)
  ret ptr %rn
fail:
  ret ptr null
}


define ptr @path.normalize(ptr %s) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %empty, label %alloc
empty:
  %e = getelementptr inbounds [1 x i8], ptr @.path.empty, i64 0, i64 0
  %re = call ptr @lith_path_dup_range(ptr %e, i64 0, i64 0)
  ret ptr %re
alloc:
  %n = call i64 @strlen(ptr %s)
  %size = add i64 %n, 1
  %out = call ptr @malloc(i64 %size)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %loop
loop:
  %i = phi i64 [0, %alloc], [%inext, %store], [%inext2, %skip]
  %j = phi i64 [0, %alloc], [%jnext, %store], [%j, %skip]
  %prevsep = phi i1 [false, %alloc], [%sep, %store], [%prevsep, %skip]
  %done = icmp uge i64 %i, %n
  br i1 %done, label %finish, label %read
read:
  %p = getelementptr i8, ptr %s, i64 %i
  %c0 = load i8, ptr %p
  %sep = call i1 @lith_path_is_sep(i8 %c0)
  %dupe = and i1 %sep, %prevsep
  br i1 %dupe, label %skip, label %store
skip:
  %inext2 = add i64 %i, 1
  br label %loop
store:
  %c = select i1 %sep, i8 47, i8 %c0
  %dst = getelementptr i8, ptr %out, i64 %j
  store i8 %c, ptr %dst
  %inext = add i64 %i, 1
  %jnext = add i64 %j, 1
  br label %loop
finish:
  %end = getelementptr i8, ptr %out, i64 %j
  store i8 0, ptr %end
  ret ptr %out
fail:
  ret ptr null
}
