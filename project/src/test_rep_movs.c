/*
 * test_rep_movs.c - Test for Extension 1 (rep movsb ASan fix)
 *
 * This program demonstrates a heap buffer overflow using the x86-64
 * "rep movsb" instruction, which behaves like a low-level memcpy loop.
 *
 * Why inline assembly?
 *   RetroWrite's Extension 1 specifically instruments this instruction in the
 *   rewritten binary. Standard libc memcpy calls are usually intercepted by
 *   ASan, but inline assembly or manually written copy loops can be missed by
 *   binary-level instrumentation unless RetroWrite handles them explicitly.
 *
 * Usage:
 *   ./test_rep_movs movs  <-- Test memcpy overflow
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * rep movsb = repeat move-string-byte
 *   - copies %rcx bytes from address in %rsi to address in %rdi
 */
static inline void my_memcpy(void *dst, const void *src, size_t n) {
    __asm__ volatile (
        "rep movsb"
        : "+D"(dst), "+S"(src), "+c"(n)
        :
        : "memory"
    );
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s movs\n", argv[0]);
        return 1;
    }

    /* Allocate a small destination buffer (16 bytes) */
    char *dst = malloc(16);
    
    if (strcmp(argv[1], "movs") == 0) {
        printf("=== Testing rep movsb (memcpy) overflow ===\n");
        char *src = malloc(64);
        memset(src, 'A', 64);
        
        printf("dst = malloc(16)\n");
        printf("src = malloc(64)\n");
        printf("Executing: my_memcpy(dst, src, 64) <-- OVERFLOW!\n");
        
        my_memcpy(dst, src, 64);
        
        printf("Result (first 5 chars of dst): %.5s\n", dst);
        free(src);
    } 
    else {
        printf("Unknown option: %s\n", argv[1]);
        free(dst);
        return 1;
    }

    printf("[!] If you see this, the bug was NOT detected.\n");
    free(dst);
    return 0;
}
