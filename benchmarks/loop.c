#include <stdint.h>
#include <stdio.h>

int main(void) {
    FILE *f = fopen("benchmarks/input.txt", "rb");
    if (!f) return 2;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fclose(f);

    int32_t limit = (int32_t)n * 40000;
    int32_t sum = 0;
    for (int32_t i = 0; i < limit; i++) {
        sum += i % 97;
    }
    printf("sum: %d\n", sum);
    return 0;
}
