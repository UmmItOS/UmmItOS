#version 440

// The picture fading out toward its rounded edge, like a feathered mask.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    float spread;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    vec2 q = abs(p) - (size * 0.5 - radius);
    // Distance to the rounded edge, negative inside.
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float keep = smoothstep(0.0, spread, -d);
    fragColor = texture(source, qt_TexCoord0) * keep * qt_Opacity;
}
