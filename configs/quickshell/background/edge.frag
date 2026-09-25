#version 440

// Ink that thickens toward a rounded rectangle's edge: an inner shadow. Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    float spread;
    float strength;
    vec4 ink;
};

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    vec2 q = abs(p) - (size * 0.5 - radius);
    // Distance to the rounded edge, negative inside.
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float edge = 1.0 - smoothstep(0.0, spread, -d);
    fragColor = vec4(ink.rgb, 1.0) * edge * edge * strength * qt_Opacity;
}
