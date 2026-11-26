#version 440

// The source with its left and right edges faded to nothing; `showLeft` and `showRight` say how much of each fade shows, `edge` is its width as a share of the whole. Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float showLeft;
    float showRight;
    float edge;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float l = mix(1.0, smoothstep(0.0, edge, qt_TexCoord0.x), showLeft);
    float r = mix(1.0, smoothstep(0.0, edge, 1.0 - qt_TexCoord0.x), showRight);
    fragColor = texture(source, qt_TexCoord0) * l * r * qt_Opacity;
}
