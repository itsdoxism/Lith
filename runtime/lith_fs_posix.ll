; Lith POSIX directory runtime.
; Generic filesystem code stays in lith_fs.ll; directory enumeration is isolated here
; because POSIX dirent layout is platform ABI. Current implementation targets Linux/glibc.

@.lith.fs.dot = private unnamed_addr constant [2 x i8] c"\2E\00", align 1
@.lith.fs.dotdot = private unnamed_addr constant [3 x i8] c"\2E\2E\00", align 1

declare i32 @mkdir(ptr, i32)
declare i32 @rmdir(ptr)
declare i32 @chdir(ptr)
declare ptr @getcwd(ptr, i64)
declare ptr @opendir(ptr)
declare ptr @readdir(ptr)
declare i32 @closedir(ptr)
declare i64 @strlen(ptr)
declare i32 @strcmp(ptr, ptr)
declare ptr @malloc(i64)
declare ptr @realloc(ptr, i64)
declare void @free(ptr)
declare ptr @memcpy(ptr, ptr, i64)

define i32 @fs.mkdir(ptr %path) {
entry:
  %status = call i32 @mkdir(ptr %path, i32 511)
  %ok = icmp eq i32 %status, 0
  %out = zext i1 %ok to i32
  ret i32 %out
}

define i32 @fs.rmdir(ptr %path) {
entry:
  %status = call i32 @rmdir(ptr %path)
  %ok = icmp eq i32 %status, 0
  %out = zext i1 %ok to i32
  ret i32 %out
}

define i32 @fs.chdir(ptr %path) {
entry:
  %status = call i32 @chdir(ptr %path)
  %ok = icmp eq i32 %status, 0
  %out = zext i1 %ok to i32
  ret i32 %out
}

define ptr @fs.cwd() {
entry:
  %buf = call ptr @malloc(i64 4096)
  %bad = icmp eq ptr %buf, null
  br i1 %bad, label %fail, label %read
read:
  %got = call ptr @getcwd(ptr %buf, i64 4096)
  %null = icmp eq ptr %got, null
  br i1 %null, label %freefail, label %done
done:
  ret ptr %buf
freefail:
  call void @free(ptr %buf)
  ret ptr null
fail:
  ret ptr null
}

define internal ptr @lith_fs_list_append(ptr %buf, i64 %len, ptr %name, i64 %nlen) {
entry:
  %extra = add i64 %nlen, 1
  %newlen = add i64 %len, %extra
  %size = add i64 %newlen, 1
  %next = call ptr @realloc(ptr %buf, i64 %size)
  %bad = icmp eq ptr %next, null
  br i1 %bad, label %fail, label %copy
copy:
  %dst = getelementptr i8, ptr %next, i64 %len
  %ignored = call ptr @memcpy(ptr %dst, ptr %name, i64 %nlen)
  %nlp = getelementptr i8, ptr %dst, i64 %nlen
  store i8 10, ptr %nlp
  %end = getelementptr i8, ptr %next, i64 %newlen
  store i8 0, ptr %end
  ret ptr %next
fail:
  ret ptr null
}

define ptr @fs.list(ptr %path) {
entry:
  %dir = call ptr @opendir(ptr %path)
  %bad = icmp eq ptr %dir, null
  br i1 %bad, label %fail, label %alloc
alloc:
  %buf = call ptr @malloc(i64 1)
  %oom = icmp eq ptr %buf, null
  br i1 %oom, label %closefail, label %init
init:
  store i8 0, ptr %buf
  br label %loop
loop:
  %curbuf = phi ptr [%buf, %init], [%nextbuf, %appenddone], [%curbuf, %skip]
  %curlen = phi i64 [0, %init], [%newlen2, %appenddone], [%curlen, %skip]
  %ent = call ptr @readdir(ptr %dir)
  %done = icmp eq ptr %ent, null
  br i1 %done, label %finish, label %name
name:
  ; Linux/glibc struct dirent has d_name at byte offset 19.
  %nameptr = getelementptr i8, ptr %ent, i64 19
  %dot = getelementptr inbounds [2 x i8], ptr @.lith.fs.dot, i64 0, i64 0
  %dotdot = getelementptr inbounds [3 x i8], ptr @.lith.fs.dotdot, i64 0, i64 0
  %cdot = call i32 @strcmp(ptr %nameptr, ptr %dot)
  %isdot = icmp eq i32 %cdot, 0
  br i1 %isdot, label %skip, label %checkdotdot
checkdotdot:
  %cdd = call i32 @strcmp(ptr %nameptr, ptr %dotdot)
  %isdd = icmp eq i32 %cdd, 0
  br i1 %isdd, label %skip, label %append
append:
  %nlen = call i64 @strlen(ptr %nameptr)
  %nextbuf = call ptr @lith_fs_list_append(ptr %curbuf, i64 %curlen, ptr %nameptr, i64 %nlen)
  %appendbad = icmp eq ptr %nextbuf, null
  br i1 %appendbad, label %freeclosefail, label %appenddone
appenddone:
  %newlen = add i64 %curlen, %nlen
  %newlen2 = add i64 %newlen, 1
  br label %loop
skip:
  br label %loop
finish:
  %closed = call i32 @closedir(ptr %dir)
  ret ptr %curbuf
freeclosefail:
  call void @free(ptr %curbuf)
  %cc0 = call i32 @closedir(ptr %dir)
  ret ptr null
closefail:
  %cc1 = call i32 @closedir(ptr %dir)
  ret ptr null
fail:
  ret ptr null
}
