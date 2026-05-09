/*
 * test_coverage.c - Test case for Extension 2 (basic block coverage)
 *
 * This program has multiple code paths controlled by input.
 * After RetroWrite coverage instrumentation, each basic block
 * is tracked in a coverage bitmap.
 *
 * Compile: clang -O0 -fPIC -fPIE -pie test_coverage.c -o test_coverage
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int process_input(const char *input) {
    int score = 0;

    if (strlen(input) > 5) {
        score += 10;            // Path A
        if (input[0] == 'H') {
            score += 20;        // Path B
            if (input[1] == 'i') {
                score += 30;    // Path C (deep path)
            }
        }
    } else {
        score -= 5;             // Path D
    }

    if (score > 25) {
        printf("[+] High score path: %d\n", score);   // Path E
    } else if (score > 0) {
        printf("[=] Medium score path: %d\n", score);  // Path F
    } else {
        printf("[-] Low score path: %d\n", score);     // Path G
    }

    return score;
}

void loop_paths(int n) {
    for (int i = 0; i < n; i++) {
        if (i % 3 == 0) {
            printf("  fizz(%d) ", i);     // Path H
        } else if (i % 3 == 1) {
            printf("  buzz(%d) ", i);     // Path I
        } else {
            printf("  norm(%d) ", i);     // Path J
        }
    }
    printf("\n");
}

int main(int argc, char **argv) {
    printf("=== Coverage Test Program ===\n");
    printf("This program has 10+ basic blocks across multiple paths.\n\n");

    if (argc > 1) {
        printf("Processing input: '%s'\n", argv[1]);
        process_input(argv[1]);
    } else {
        printf("No input - testing default paths\n");
        process_input("short");
        process_input("Hello World");
        process_input("Hi there!");
    }

    printf("\nLoop paths:\n");
    loop_paths(6);

    printf("\nDone. Coverage bitmap should show visited blocks.\n");
    return 0;
}
