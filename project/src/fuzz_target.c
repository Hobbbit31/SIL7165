#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// A simple program with bugs that AFL can find via stdin input
void process_input(char *buf, int len) {
    char local[32];

    if (len > 0 && buf[0] == 'F') {
        if (len > 1 && buf[1] == 'U') {
            if (len > 2 && buf[2] == 'Z') {
                if (len > 3 && buf[3] == 'Z') {
                    // Trigger a heap buffer overflow
                    char *heap = (char *)malloc(8);
                    memcpy(heap, buf, len); // overflow if len > 8
                    free(heap);
                }
            }
        }
    }

    if (len > 4 && buf[0] == 'C' && buf[1] == 'R' &&
        buf[2] == 'A' && buf[3] == 'S' && buf[4] == 'H') {
        // Trigger a null pointer dereference
        char *p = NULL;
        *p = buf[5];
    }

    if (len > 2) {
        memcpy(local, buf, len); // stack overflow if len > 32
    }
}

int main() {
    char buf[256];
    int len = fread(buf, 1, sizeof(buf), stdin);
    if (len > 0) {
        process_input(buf, len);
    }
    return 0;
}
