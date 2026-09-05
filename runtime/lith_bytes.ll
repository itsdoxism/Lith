; Lith binary byte-buffer runtime.
; Object layout: [i64 length][raw bytes...]. Data is not NUL-terminated and may contain zero bytes.

declare ptr @malloc(i64)
declare void @free(ptr)
declare i64 @strlen(ptr)
declare ptr @memcpy(ptr, ptr, i64)
declare ptr @memset(ptr, i32, i64)
declare i32 @memcmp(ptr, ptr, i64)

define internal ptr @lith_bytes_data(ptr %b) {
entry:
  %null = icmp eq ptr %b, null
  br i1 %null, label %fail, label %ok
ok:
  %data = getelementptr i8, ptr %b, i64 8
  ret ptr %data
fail:
  ret ptr null
}

define ptr @lith_bytes_alloc(i32 %n0) {
entry:
  %neg = icmp slt i32 %n0, 0
  %n = select i1 %neg, i32 0, i32 %n0
  %n64 = zext i32 %n to i64
  %total = add i64 %n64, 8
  %obj = call ptr @malloc(i64 %total)
  %bad = icmp eq ptr %obj, null
  br i1 %bad, label %fail, label %init
init:
  store i64 %n64, ptr %obj
  %data = getelementptr i8, ptr %obj, i64 8
  %ignored = call ptr @memset(ptr %data, i32 0, i64 %n64)
  ret ptr %obj
fail:
  ret ptr null
}

define ptr @lith_bytes_from_str(ptr %s) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %empty, label %work
empty:
  %z = call ptr @lith_bytes_alloc(i32 0)
  ret ptr %z
work:
  %n64 = call i64 @strlen(ptr %s)
  %n = trunc i64 %n64 to i32
  %obj = call ptr @lith_bytes_alloc(i32 %n)
  %bad = icmp eq ptr %obj, null
  br i1 %bad, label %fail, label %copy
copy:
  %data = call ptr @lith_bytes_data(ptr %obj)
  %ignored = call ptr @memcpy(ptr %data, ptr %s, i64 %n64)
  ret ptr %obj
fail:
  ret ptr null
}

define ptr @lith_bytes_to_str(ptr %b) {
entry:
  %null = icmp eq ptr %b, null
  br i1 %null, label %empty, label %work
empty:
  %out0 = call ptr @malloc(i64 1)
  %bad0 = icmp eq ptr %out0, null
  br i1 %bad0, label %fail, label %emptyok
emptyok:
  store i8 0, ptr %out0
  ret ptr %out0
work:
  %n = load i64, ptr %b
  %size = add i64 %n, 1
  %out = call ptr @malloc(i64 %size)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %copy
copy:
  %data = call ptr @lith_bytes_data(ptr %b)
  %ignored = call ptr @memcpy(ptr %out, ptr %data, i64 %n)
  %end = getelementptr i8, ptr %out, i64 %n
  store i8 0, ptr %end
  ret ptr %out
fail:
  ret ptr null
}

define i32 @lith_bytes_len(ptr %b) {
entry:
  %null = icmp eq ptr %b, null
  br i1 %null, label %zero, label %work
work:
  %n = load i64, ptr %b
  %out = trunc i64 %n to i32
  ret i32 %out
zero:
  ret i32 0
}

define i32 @lith_bytes_at(ptr %b, i32 %index) {
entry:
  %null = icmp eq ptr %b, null
  %neg = icmp slt i32 %index, 0
  %bad0 = or i1 %null, %neg
  br i1 %bad0, label %zero, label %bounds
bounds:
  %n = load i64, ptr %b
  %i = zext i32 %index to i64
  %oob = icmp uge i64 %i, %n
  br i1 %oob, label %zero, label %load
load:
  %data = call ptr @lith_bytes_data(ptr %b)
  %p = getelementptr i8, ptr %data, i64 %i
  %v = load i8, ptr %p
  %out = zext i8 %v to i32
  ret i32 %out
zero:
  ret i32 0
}

define i32 @lith_bytes_set(ptr %b, i32 %index, i32 %value) {
entry:
  %null = icmp eq ptr %b, null
  %neg = icmp slt i32 %index, 0
  %bad0 = or i1 %null, %neg
  br i1 %bad0, label %fail, label %bounds
bounds:
  %n = load i64, ptr %b
  %i = zext i32 %index to i64
  %oob = icmp uge i64 %i, %n
  br i1 %oob, label %fail, label %store
store:
  %data = call ptr @lith_bytes_data(ptr %b)
  %p = getelementptr i8, ptr %data, i64 %i
  %v = trunc i32 %value to i8
  store i8 %v, ptr %p
  ret i32 1
fail:
  ret i32 0
}

define ptr @lith_bytes_slice(ptr %b, i32 %start0, i32 %end0) {
entry:
  %null = icmp eq ptr %b, null
  br i1 %null, label %empty, label %work
empty:
  %z = call ptr @lith_bytes_alloc(i32 0)
  ret ptr %z
work:
  %n64 = load i64, ptr %b
  %n = trunc i64 %n64 to i32
  %sneg = icmp slt i32 %start0, 0
  %s1 = select i1 %sneg, i32 0, i32 %start0
  %sgt = icmp sgt i32 %s1, %n
  %start = select i1 %sgt, i32 %n, i32 %s1
  %elt = icmp slt i32 %end0, %start
  %e1 = select i1 %elt, i32 %start, i32 %end0
  %egt = icmp sgt i32 %e1, %n
  %end = select i1 %egt, i32 %n, i32 %e1
  %len = sub i32 %end, %start
  %out = call ptr @lith_bytes_alloc(i32 %len)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %copy
copy:
  %src0 = call ptr @lith_bytes_data(ptr %b)
  %start64 = zext i32 %start to i64
  %src = getelementptr i8, ptr %src0, i64 %start64
  %dst = call ptr @lith_bytes_data(ptr %out)
  %len64 = zext i32 %len to i64
  %ignored = call ptr @memcpy(ptr %dst, ptr %src, i64 %len64)
  ret ptr %out
fail:
  ret ptr null
}

define ptr @lith_bytes_concat(ptr %a, ptr %b) {
entry:
  %an = icmp eq ptr %a, null
  %bn = icmp eq ptr %b, null
  %na0 = select i1 %an, i64 0, i64 1
  br i1 %an, label %alen0, label %alen
alen:
  %na1 = load i64, ptr %a
  br label %ajoin
alen0:
  br label %ajoin
ajoin:
  %na = phi i64 [0, %alen0], [%na1, %alen]
  br i1 %bn, label %blen0, label %blen
blen:
  %nb1 = load i64, ptr %b
  br label %bjoin
blen0:
  br label %bjoin
bjoin:
  %nb = phi i64 [0, %blen0], [%nb1, %blen]
  %sum = add i64 %na, %nb
  %sum32 = trunc i64 %sum to i32
  %out = call ptr @lith_bytes_alloc(i32 %sum32)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %copya
copya:
  %dst = call ptr @lith_bytes_data(ptr %out)
  br i1 %an, label %copyb, label %copya2
copya2:
  %ad = call ptr @lith_bytes_data(ptr %a)
  %ia = call ptr @memcpy(ptr %dst, ptr %ad, i64 %na)
  br label %copyb
copyb:
  br i1 %bn, label %done, label %copyb2
copyb2:
  %bd = call ptr @lith_bytes_data(ptr %b)
  %dstb = getelementptr i8, ptr %dst, i64 %na
  %ib = call ptr @memcpy(ptr %dstb, ptr %bd, i64 %nb)
  br label %done
done:
  ret ptr %out
fail:
  ret ptr null
}

define i32 @lith_bytes_eq(ptr %a, ptr %b) {
entry:
  %an = icmp eq ptr %a, null
  %bn = icmp eq ptr %b, null
  %either = or i1 %an, %bn
  br i1 %either, label %ptrcmp, label %lengths
ptrcmp:
  %same = icmp eq ptr %a, %b
  %pr = zext i1 %same to i32
  ret i32 %pr
lengths:
  %na = load i64, ptr %a
  %nb = load i64, ptr %b
  %same_len = icmp eq i64 %na, %nb
  br i1 %same_len, label %cmp, label %no
cmp:
  %ad = call ptr @lith_bytes_data(ptr %a)
  %bd = call ptr @lith_bytes_data(ptr %b)
  %c = call i32 @memcmp(ptr %ad, ptr %bd, i64 %na)
  %same_data = icmp eq i32 %c, 0
  %out = zext i1 %same_data to i32
  ret i32 %out
no:
  ret i32 0
}

define ptr @lith_bytes_ptr(ptr %b) {
entry:
  %data = call ptr @lith_bytes_data(ptr %b)
  ret ptr %data
}

define i32 @lith_bytes_free(ptr %b) {
entry:
  %null = icmp eq ptr %b, null
  br i1 %null, label %zero, label %work
work:
  call void @free(ptr %b)
  ret i32 1
zero:
  ret i32 0
}
