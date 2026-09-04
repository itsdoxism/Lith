#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    FILE *f = fopen("benchmarks/input.txt", "rb");
    if (!f) return 2;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fclose(f);

    int32_t count = (int32_t)n * 1000;
    int32_t *values = malloc((size_t)count * sizeof(int32_t));
    if (!values) return 3;
    for (int32_t i = 0; i < count; i++) values[i] = i % 97;
    int32_t sum = 0;
    for (int32_t i = 0; i < count; i++) {
        int32_t tmp = sum + values[i];
        sum = tmp % 1000000007;
    }
    printf("sum: %d\n", sum);
    free(values);
    return 0;
}
