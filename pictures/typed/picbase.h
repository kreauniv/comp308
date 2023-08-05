
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef struct {
    float a, r, g, b;
} color;

float min(float a, float b) {
    return a < b ? a : b;
}

color argb(float a, float r, float g, float b) {
    color c;
    c.a = a;
    c.r = r;
    c.g = g;
    c.b = b;
    return c;
}

color mix(color ca, color cb) {
    color c;
    float a = ca.a + cb.a;
    c.a = a;
    c.r = (ca.a * ca.r + cb.a * cb.r) / a;
    c.g = (ca.a * ca.g + cb.a * cb.g) / a;
    c.b = (ca.a * ca.b + cb.a * cb.b) / a;
    return c;
}

/*
 * (overlay
    (colorize 1.0 1.0 0.0 0.0 (circle 1.0 0.1))
    (translate 0.5 0.0 (colorize 1.0 0.0 0.0 1.0 (circle 1.5 0.1)))))
    */

int quantize(float q) {
    return (int)floor(q * 255.99);
}

void write_ppm(int nx, int ny, const color *image) {
    printf("P3\n%d\n%d\n%d\n", nx, ny, 255);
    for (int r = 0; r < ny; ++r) {
        for (int c = 0; c < nx; ++c) {
            color col = image[r * nx + c];
            printf("%d %d %d ", quantize(col.r), quantize(col.g), quantize(col.b));
        }
        printf("\n");
    }
}

