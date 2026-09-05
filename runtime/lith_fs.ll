; Lith binary filesystem runtime.
; Reads/writes the length-prefixed `bytes` object used by runtime/lith_bytes.ll.

@.lith.fs.rb = private unnamed_addr constant [3 x i8] c"\72\62\00", align 1
@.lith.fs.wb = private unnamed_addr constant [3 x i8] c"\77\62\00", align 1

declare ptr @fopen(ptr, ptr)
declare i32 @fseek(ptr, i64, i32)
declare i64 @ftell(ptr)
declare void @rewind(ptr)
declare i64 @fread(ptr, i64, i64, ptr)
declare i64 @fwrite(ptr, i64, i64, ptr)
declare i32 @fclose(ptr)
declare ptr @lith_bytes_alloc(i32)
declare i32 @lith_bytes_len(ptr)
declare ptr @lith_bytes_ptr(ptr)
declare i32 @lith_bytes_free(ptr)

define ptr @fs.read_bytes(ptr %path) {
entry:
  %mode = getelementptr inbounds [3 x i8], ptr @.lith.fs.rb, i64 0, i64 0
  %f = call ptr @fopen(ptr %path, ptr %mode)
  %badf = icmp eq ptr %f, null
  br i1 %badf, label %fail, label %seek
seek:
  %sr = call i32 @fseek(ptr %f, i64 0, i32 2)
  %seekbad = icmp ne i32 %sr, 0
  br i1 %seekbad, label %closefail, label %tell
tell:
  %n64 = call i64 @ftell(ptr %f)
  %neg = icmp slt i64 %n64, 0
  %too_big = icmp sgt i64 %n64, 2147483647
  %invalid = or i1 %neg, %too_big
  br i1 %invalid, label %closefail, label %alloc
alloc:
  call void @rewind(ptr %f)
  %n = trunc i64 %n64 to i32
  %out = call ptr @lith_bytes_alloc(i32 %n)
  %oom = icmp eq ptr %out, null
  br i1 %oom, label %closefail, label %read
read:
  %data = call ptr @lith_bytes_ptr(ptr %out)
  %got = call i64 @fread(ptr %data, i64 1, i64 %n64, ptr %f)
  %cr = call i32 @fclose(ptr %f)
  %short = icmp ne i64 %got, %n64
  %closebad = icmp ne i32 %cr, 0
  %bad = or i1 %short, %closebad
  br i1 %bad, label %freefail, label %done
done:
  ret ptr %out
freefail:
  %ignored = call i32 @lith_bytes_free(ptr %out)
  ret ptr null
closefail:
  %cc = call i32 @fclose(ptr %f)
  ret ptr null
fail:
  ret ptr null
}

define i32 @fs.write_bytes(ptr %path, ptr %bytes) {
entry:
  %null = icmp eq ptr %bytes, null
  br i1 %null, label %fail, label %open
open:
  %mode = getelementptr inbounds [3 x i8], ptr @.lith.fs.wb, i64 0, i64 0
  %f = call ptr @fopen(ptr %path, ptr %mode)
  %badf = icmp eq ptr %f, null
  br i1 %badf, label %fail, label %write
write:
  %n32 = call i32 @lith_bytes_len(ptr %bytes)
  %n = zext i32 %n32 to i64
  %data = call ptr @lith_bytes_ptr(ptr %bytes)
  %wrote = call i64 @fwrite(ptr %data, i64 1, i64 %n, ptr %f)
  %cr = call i32 @fclose(ptr %f)
  %same = icmp eq i64 %wrote, %n
  %closed = icmp eq i32 %cr, 0
  %ok = and i1 %same, %closed
  %out = zext i1 %ok to i32
  ret i32 %out
fail:
  ret i32 0
}
