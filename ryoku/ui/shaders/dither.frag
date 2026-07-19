#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix; float qt_Opacity;
    vec4 bone; vec2 srcSize; float dotScale; float invert;
};
layout(binding = 1) uniform sampler2D src;
float bayer4(vec2 pos) {
    vec2 f = floor(mod(pos, 4.0));
    float i = f.y * 4.0 + f.x;
    float t = 5.5/16.0;
    if (i < 0.5) t = 0.5/16.0; else if (i < 1.5) t = 8.5/16.0;
    else if (i < 2.5) t = 2.5/16.0; else if (i < 3.5) t = 10.5/16.0;
    else if (i < 4.5) t = 12.5/16.0; else if (i < 5.5) t = 4.5/16.0;
    else if (i < 6.5) t = 14.5/16.0; else if (i < 7.5) t = 6.5/16.0;
    else if (i < 8.5) t = 3.5/16.0; else if (i < 9.5) t = 11.5/16.0;
    else if (i < 10.5) t = 1.5/16.0; else if (i < 11.5) t = 9.5/16.0;
    else if (i < 12.5) t = 15.5/16.0; else if (i < 13.5) t = 7.5/16.0;
    else if (i < 14.5) t = 13.5/16.0;
    return t;
}
void main() {
    vec4 c = texture(src, qt_TexCoord0);
    float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    vec2 px = qt_TexCoord0 * srcSize / max(dotScale, 1.0);
    float thr = bayer4(px);
    float ink = (invert > 0.5) ? step(lum, thr) : step(thr, lum);
    ink *= step(0.004, c.a);
    fragColor = vec4(bone.rgb, 1.0) * ink * qt_Opacity;
}
