; Lith POSIX process runtime.
; Direct fork/execvp/waitpid execution without shell command parsing.
; `args` is a newline-separated argument list. Each non-empty line becomes one argv entry.

@.lith.process.nl = private unnamed_addr constant [2 x i8] c"\0A\00", align 1

declare i32 @fork()
declare i32 @getpid()
declare i32 @execvp(ptr, ptr)
declare i32 @waitpid(i32, ptr, i32)
declare void @_exit(i32)
declare i64 @strlen(ptr)
declare ptr @malloc(i64)
declare ptr @realloc(ptr, i64)
declare void @free(ptr)
declare ptr @memcpy(ptr, ptr, i64)

define i32 @process.pid() {
entry:
  %pid = call i32 @getpid()
  ret i32 %pid
}

define internal ptr @lith_process_dup(ptr %s) {
entry:
  %null = icmp eq ptr %s, null
  br i1 %null, label %empty, label %work
empty:
  %z = call ptr @malloc(i64 1)
  %badz = icmp eq ptr %z, null
  br i1 %badz, label %fail, label %zok
zok:
  store i8 0, ptr %z
  ret ptr %z
work:
  %n = call i64 @strlen(ptr %s)
  %size = add i64 %n, 1
  %out = call ptr @malloc(i64 %size)
  %bad = icmp eq ptr %out, null
  br i1 %bad, label %fail, label %copy
copy:
  %ignored = call ptr @memcpy(ptr %out, ptr %s, i64 %size)
  ret ptr %out
fail:
  ret ptr null
}

define internal i32 @lith_process_count_args(ptr %args) {
entry:
  %null = icmp eq ptr %args, null
  br i1 %null, label %zero, label %scan
scan:
  %first = load i8, ptr %args
  %empty = icmp eq i8 %first, 0
  br i1 %empty, label %zero, label %loop
loop:
  %i = phi i64 [0, %scan], [%next, %step]
  %count = phi i32 [1, %scan], [%count2, %step]
  %p = getelementptr i8, ptr %args, i64 %i
  %ch = load i8, ptr %p
  %end = icmp eq i8 %ch, 0
  br i1 %end, label %done, label %check
check:
  %isnl = icmp eq i8 %ch, 10
  %nextp = getelementptr i8, ptr %p, i64 1
  %nextch = load i8, ptr %nextp
  %nextnonempty = icmp ne i8 %nextch, 0
  %boundary = and i1 %isnl, %nextnonempty
  %inc = zext i1 %boundary to i32
  %count2 = add i32 %count, %inc
  br label %step
step:
  %next = add i64 %i, 1
  br label %loop
done:
  ret i32 %count
zero:
  ret i32 0
}

define internal ptr @lith_process_build_argv(ptr %program, ptr %args) {
entry:
  %argc_extra = call i32 @lith_process_count_args(ptr %args)
  %argc = add i32 %argc_extra, 1
  %slots32 = add i32 %argc, 1
  %slots = zext i32 %slots32 to i64
  %bytes = mul i64 %slots, 8
  %argv = call ptr @malloc(i64 %bytes)
  %bad = icmp eq ptr %argv, null
  br i1 %bad, label %fail, label %programslot
programslot:
  %p0 = getelementptr ptr, ptr %argv, i64 0
  store ptr %program, ptr %p0
  %none = icmp eq i32 %argc_extra, 0
  br i1 %none, label %terminate, label %copyargs
copyargs:
  %copy = call ptr @lith_process_dup(ptr %args)
  %copybad = icmp eq ptr %copy, null
  br i1 %copybad, label %freefail, label %split
split:
  %firstslot = getelementptr ptr, ptr %argv, i64 1
  store ptr %copy, ptr %firstslot
  br label %loop
loop:
  %i = phi i64 [0, %split], [%next, %step]
  %slot = phi i32 [1, %split], [%slot2, %step]
  %p = getelementptr i8, ptr %copy, i64 %i
  %ch = load i8, ptr %p
  %end = icmp eq i8 %ch, 0
  br i1 %end, label %terminate, label %check
check:
  %isnl = icmp eq i8 %ch, 10
  br i1 %isnl, label %newline, label %same
newline:
  store i8 0, ptr %p
  %nextp = getelementptr i8, ptr %p, i64 1
  %nextch = load i8, ptr %nextp
  %hasnext = icmp ne i8 %nextch, 0
  br i1 %hasnext, label %addslot, label %same
addslot:
  %slotnext = add i32 %slot, 1
  %slot64 = zext i32 %slotnext to i64
  %sp = getelementptr ptr, ptr %argv, i64 %slot64
  store ptr %nextp, ptr %sp
  br label %step2
same:
  br label %step
step2:
  br label %step
step:
  %slot2 = phi i32 [%slot, %same], [%slotnext, %step2]
  %next = add i64 %i, 1
  br label %loop
terminate:
  %argc64 = zext i32 %argc to i64
  %endp = getelementptr ptr, ptr %argv, i64 %argc64
  store ptr null, ptr %endp
  ret ptr %argv
freefail:
  call void @free(ptr %argv)
  ret ptr null
fail:
  ret ptr null
}

define i32 @process.spawn(ptr %program, ptr %args) {
entry:
  %argv = call ptr @lith_process_build_argv(ptr %program, ptr %args)
  %bad = icmp eq ptr %argv, null
  br i1 %bad, label %fail, label %forkit
forkit:
  %pid = call i32 @fork()
  %forkbad = icmp slt i32 %pid, 0
  br i1 %forkbad, label %freefail, label %which
which:
  %child = icmp eq i32 %pid, 0
  br i1 %child, label %childpath, label %parent
childpath:
  %rc = call i32 @execvp(ptr %program, ptr %argv)
  call void @_exit(i32 127)
  unreachable
parent:
  call void @free(ptr %argv)
  ret i32 %pid
freefail:
  call void @free(ptr %argv)
  ret i32 -1
fail:
  ret i32 -1
}

define i32 @process.wait(i32 %pid) {
entry:
  %status = alloca i32
  %got = call i32 @waitpid(i32 %pid, ptr %status, i32 0)
  %bad = icmp slt i32 %got, 0
  br i1 %bad, label %fail, label %decode
; POSIX wait status: normal exit iff low 7 bits are zero; exit code lives in bits 8..15.
decode:
  %raw = load i32, ptr %status
  %sig = and i32 %raw, 127
  %normal = icmp eq i32 %sig, 0
  br i1 %normal, label %normalexit, label %signaled
normalexit:
  %shift = lshr i32 %raw, 8
  %code = and i32 %shift, 255
  ret i32 %code
signaled:
  %mapped = add i32 128, %sig
  ret i32 %mapped
fail:
  ret i32 -1
}

define i32 @process.exec(ptr %program, ptr %args) {
entry:
  %pid = call i32 @process.spawn(ptr %program, ptr %args)
  %bad = icmp slt i32 %pid, 0
  br i1 %bad, label %fail, label %wait
wait:
  %code = call i32 @process.wait(i32 %pid)
  ret i32 %code
fail:
  ret i32 -1
}
