#include "luna_runtime.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *luna_dup_range(const char *s, size_t n) {
    char *out = (char *)malloc(n + 1);
    if (!out) {
        fprintf(stderr, "luna runtime: out of memory\n");
        exit(70);
    }
    memcpy(out, s, n);
    out[n] = '\0';
    return out;
}

char *luna_read_text(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long n = ftell(f);
    if (n < 0) { fclose(f); return NULL; }
    rewind(f);
    char *buf = (char *)malloc((size_t)n + 1);
    if (!buf) { fclose(f); return NULL; }
    size_t got = fread(buf, 1, (size_t)n, f);
    fclose(f);
    if (got != (size_t)n) { free(buf); return NULL; }
    buf[n] = '\0';
    return buf;
}

int luna_write_text(const char *path, const char *text) {
    FILE *f = fopen(path, "wb");
    if (!f) return 0;
    size_t n = strlen(text);
    size_t wrote = fwrite(text, 1, n, f);
    int ok = (wrote == n) && (fclose(f) == 0);
    return ok;
}

int luna_str_len(const char *s) {
    return s ? (int)strlen(s) : 0;
}

int luna_str_at(const char *s, int index) {
    if (!s || index < 0) return 0;
    size_t n = strlen(s);
    if ((size_t)index >= n) return 0;
    return (unsigned char)s[index];
}

char *luna_str_slice(const char *s, int start, int end) {
    if (!s) return luna_dup_range("", 0);
    int n = (int)strlen(s);
    if (start < 0) start = 0;
    if (end < start) end = start;
    if (start > n) start = n;
    if (end > n) end = n;
    return luna_dup_range(s + start, (size_t)(end - start));
}

char *luna_str_concat(const char *a, const char *b) {
    if (!a) a = "";
    if (!b) b = "";
    size_t na = strlen(a), nb = strlen(b);
    char *out = (char *)malloc(na + nb + 1);
    if (!out) {
        fprintf(stderr, "luna runtime: out of memory\n");
        exit(70);
    }
    memcpy(out, a, na);
    memcpy(out + na, b, nb + 1);
    return out;
}

int luna_str_eq(const char *a, const char *b) {
    if (!a || !b) return a == b;
    return strcmp(a, b) == 0;
}

int luna_str_starts(const char *s, const char *prefix) {
    if (!s || !prefix) return 0;
    size_t n = strlen(prefix);
    return strncmp(s, prefix, n) == 0;
}

char *luna_str_trim(const char *s) {
    if (!s) return luna_dup_range("", 0);
    const char *a = s;
    while (*a == ' ' || *a == '\t' || *a == '\r' || *a == '\n') ++a;
    const char *b = s + strlen(s);
    while (b > a && (b[-1] == ' ' || b[-1] == '\t' || b[-1] == '\r' || b[-1] == '\n')) --b;
    return luna_dup_range(a, (size_t)(b - a));
}

char *luna_str_chr(int code) {
    char *out = (char *)malloc(2);
    if (!out) {
        fprintf(stderr, "luna runtime: out of memory\n");
        exit(70);
    }
    out[0] = (char)code;
    out[1] = '\0';
    return out;
}

char *luna_int_str(int value) {
    char buf[64];
    snprintf(buf, sizeof buf, "%d", value);
    return luna_dup_range(buf, strlen(buf));
}
