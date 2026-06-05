#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float itemWidth;
    float itemHeight;
    vec4 bgColor;
    float cornerRadius;
} ubuf;

// Signed distance function for rounded rectangle
float roundedBoxSDF(vec2 center, vec2 size, float radius) {
    vec2 q = abs(center) - size + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

vec3 hash3(vec2 p) {
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)),
                  dot(p, vec2(269.5, 183.3)),
                  dot(p, vec2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

float noise(vec2 x, float iTime) {
    vec2 p = floor(x);
    vec2 f = fract(x);

    float va = 0.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 g = vec2(float(i), float(j));
            vec3 o = hash3(p + g);
            vec2 r = g - f + o.xy;
            float d = sqrt(dot(r, r));
            float ripple = max(mix(smoothstep(0.99, 0.999, max(cos(d - iTime * 2.0 + (o.x + o.y) * 5.0), 0.0)), 0.0, d), 0.0);
            va += ripple;
        }
    }

    return va;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float iTime = ubuf.time * 0.07;

    // Aspect ratio correction for circular ripples
    float aspect = ubuf.itemWidth / ubuf.itemHeight;
    vec2 uvAspect = vec2(uv.x * aspect, uv.y);

    float f = noise(6.0 * uvAspect, iTime) * smoothstep(0.0, 0.2, sin(uv.x * 3.141592) * sin(uv.y * 3.141592));

    // Calculate normal from noise for distortion
    float normalScale = 0.5;
    vec2 e = normalScale / vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 eAspect = vec2(e.x * aspect, e.y);
    float cx = noise(6.0 * (uvAspect + eAspect), iTime) * smoothstep(0.0, 0.2, sin((uv.x + e.x) * 3.141592) * sin(uv.y * 3.141592));
    float cy = noise(6.0 * (uvAspect + eAspect.yx), iTime) * smoothstep(0.0, 0.2, sin(uv.x * 3.141592) * sin((uv.y + e.y) * 3.141592));
    vec2 n = vec2(cx - f, cy - f);

    // Scale distortion back to texture space (undo aspect correction for X)
    vec2 distortion = vec2(n.x / aspect, n.y);

    // Sample source with distortion
    vec4 col = texture(source, uv + distortion);

    // Apply rounded corner mask
    vec2 pixelPos = qt_TexCoord0 * vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 center = pixelPos - vec2(ubuf.itemWidth, ubuf.itemHeight) * 0.5;
    vec2 halfSize = vec2(ubuf.itemWidth, ubuf.itemHeight) * 0.5;
    float dist = roundedBoxSDF(center, halfSize, ubuf.cornerRadius);
    float cornerMask = 1.0 - smoothstep(-1.0, 0.0, dist);

    // Output with premultiplied alpha
    float finalAlpha = col.a * ubuf.qt_Opacity * cornerMask;
    fragColor = vec4(col.rgb * finalAlpha, finalAlpha);
}
