// Embedded C with violations
#include <stdio.h>
#include <stdlib.h>

// N1: malloc without NULL check
void bad_alloc() {
    char *buf = malloc(100);
    buf[0] = 'x';  // No NULL check
}

// N2: Unbounded sprintf
void bad_sprintf(char *input) {
    char buf[64];
    sprintf(buf, "User: %s", input);
}

// N3: gets() usage
void bad_input() {
    char buf[100];
    gets(buf);
}

// N4: strcpy without bounds
void bad_copy(char *src) {
    char dest[50];
    strcpy(dest, src);
}

// M1: while(1) without break path shown
void infinite_loop() {
    while(1) {
        do_work();
    }
}
