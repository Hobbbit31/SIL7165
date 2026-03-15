#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Test 1: Large heap buffer overflow (obvious, easy to detect)
void heap_overflow() {
    printf("[*] Test: Heap buffer overflow\n");
    char *buf = (char *)malloc(32);
    memset(buf, 'A', 32);
    // Write 16 bytes past the end -- clearly into the redzone
    buf[40] = 'X';
    printf("    Wrote past buffer end\n");
    free(buf);
}

// Test 2: Use-after-free with large gap
void use_after_free() {
    printf("[*] Test: Use-after-free\n");
    char *buf = (char *)malloc(64);
    memset(buf, 'B', 64);
    free(buf);
    // Access freed memory
    printf("    Reading freed memory: %c\n", buf[0]);
}

// Test 3: Stack buffer overflow
void stack_overflow() {
    printf("[*] Test: Stack buffer overflow\n");
    char buf[16];
    // Overflow stack buffer by writing 48 bytes into 16-byte buffer
    memset(buf, 'C', 48);
    printf("    Overflowed stack buffer\n");
}

// Test 4: Double free
void double_free() {
    printf("[*] Test: Double free\n");
    char *buf = (char *)malloc(32);
    free(buf);
    free(buf);
}

void usage(char *prog) {
    printf("Usage: %s {1|2|3|4}\n", prog);
    printf("  1: Heap buffer overflow\n");
    printf("  2: Use-after-free\n");
    printf("  3: Stack buffer overflow\n");
    printf("  4: Double free\n");
    exit(1);
}

int main(int argc, char *argv[]) {
    if (argc != 2) usage(argv[0]);
    switch (atoi(argv[1])) {
        case 1: heap_overflow(); break;
        case 2: use_after_free(); break;
        case 3: stack_overflow(); break;
        case 4: double_free(); break;
        default: usage(argv[0]);
    }
    printf("[+] Program exited normally (bug went undetected!)\n");
    return 0;
}
