/*
 * test_trace.c - Test case for Extension 3 (function call tracing)
 *
 * This program calls multiple functions in sequence.
 * After RetroWrite trace instrumentation, every function entry
 * is logged to stderr when RETRO_TRACE_PRINT=1.
 *
 * Compile: clang -O0 -fPIC -fPIE -pie test_trace.c -o test_trace
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void helper_a() {
    printf("  -> helper_a executed\n");
}

void helper_b() {
    printf("  -> helper_b executed\n");
}

void helper_c() {
    printf("  -> helper_c executed\n");
}

int compute(int x, int y) {
    printf("  -> compute(%d, %d)\n", x, y);
    return x * y + x;
}

void process_data(const char *data) {
    printf("  -> process_data('%s')\n", data);
    int len = strlen(data);

    if (len > 5) {
        helper_a();
        int result = compute(len, 3);
        printf("  -> result = %d\n", result);
    } else {
        helper_b();
    }
    helper_c();
}

void cleanup() {
    printf("  -> cleanup done\n");
}

int main(int argc, char **argv) {
    printf("=== Function Trace Test ===\n");
    printf("Run with: RETRO_TRACE_PRINT=1 ./test_trace_traced\n");
    printf("to see function call traces on stderr.\n\n");

    printf("[1] Calling process_data with short input:\n");
    process_data("Hi");

    printf("\n[2] Calling process_data with long input:\n");
    process_data("Hello World");

    printf("\n[3] Direct function calls:\n");
    helper_a();
    helper_b();
    compute(7, 8);

    cleanup();

    printf("\nDone.\n");
    return 0;
}
