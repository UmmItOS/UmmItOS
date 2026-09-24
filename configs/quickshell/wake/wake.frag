#version 440

// The waking screen's two circles in one pass: black outside the opening
// circle, the dim haze (the blurred picture, or a plain veil) between it and
// the clearing circle, and nothing inside, where the live screen shows.
// Both edges are soft over `soft` pixels. Premultiplied output.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float rOpen;
    float rClear;
    float soft;
    float dim;
    float hasPicture;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = distance(p, size * 0.5);
    float black = smoothstep(rOpen, rOpen + soft, d);
    float haze = smoothstep(rClear, rClear + soft, d);
    vec4 picture = texture(source, qt_TexCoord0);
    vec4 hazeColour = hasPicture > 0.5 ? vec4(picture.rgb * (1.0 - dim), 1.0) : vec4(0.0, 0.0, 0.0, dim);
    vec4 colour = vec4(0.0, 0.0, 0.0, 1.0) * black + hazeColour * haze * (1.0 - black);
    fragColor = colour * qt_Opacity;
}
