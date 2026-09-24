#version 440

// The waking screen in one pass: black outside a circle with a soft edge
// `soft` pixels wide, and inside it the haze (the blurred, dimmed picture,
// or a plain veil) at strength `haze`, over the live screen. Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float reveal;
    float soft;
    float haze;
    float dim;
    float hasPicture;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    float black = smoothstep(reveal, reveal + soft, distance(p, size * 0.5));
    vec4 picture = texture(source, qt_TexCoord0);
    vec4 hazeColour = hasPicture > 0.5 ? vec4(picture.rgb * (1.0 - dim), 1.0) : vec4(0.0, 0.0, 0.0, dim);
    vec4 colour = vec4(0.0, 0.0, 0.0, 1.0) * black + hazeColour * haze * (1.0 - black);
    fragColor = colour * qt_Opacity;
}
