#ifndef LUNA_RUNTIME_H
#define LUNA_RUNTIME_H

#include <stddef.h>

char *luna_read_text(const char *path);
int luna_write_text(const char *path, const char *text);
int luna_str_len(const char *s);
int luna_str_at(const char *s, int index);
char *luna_str_slice(const char *s, int start, int end);
char *luna_str_concat(const char *a, const char *b);
int luna_str_eq(const char *a, const char *b);
int luna_str_starts(const char *s, const char *prefix);
char *luna_str_trim(const char *s);
char *luna_str_chr(int code);
char *luna_int_str(int value);

#endif
