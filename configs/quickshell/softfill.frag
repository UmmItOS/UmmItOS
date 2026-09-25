#version 440

// A flat fill fading out toward its rounded edge, so the card has no edge line.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    float spread;
    vec4 fill;
};

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    vec2 q = abs(p) - (size * 0.5 - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float keep = smoothstep(0.0, spread, -d);
    // Colours arrive premultiplied.
    fragColor = fill * keep * qt_Opacity;
}
