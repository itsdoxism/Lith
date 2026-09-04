#include <stdint.h>
#include <stdio.h>

int main(void) {
    FILE *f = fopen("benchmarks/input.txt", "rb");
    if (!f) return 2;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fclose(f);

    int32_t limit = (int32_t)n * 5000;
    int32_t values[8] = {1,2,3,4,5,6,7,8};
    int32_t sum = 0;
    for (int32_t i = 0; i < limit; i++) {
        int32_t idx = i % 8;
        int32_t x = values[idx];
        int32_t tmp = sum + x;
        sum = tmp % 1000000007;
        values[idx] = x + 1;
    }
    printf("sum: %d\n", sum);
    return 0;
}
