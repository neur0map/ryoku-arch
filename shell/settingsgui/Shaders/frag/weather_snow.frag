#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

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

void main() {
    // Aspect ratio correction
    float aspect = ubuf.itemWidth / ubuf.itemHeight;
    vec2 uv = qt_TexCoord0;
    uv.x *= aspect;
    uv.y = 1.0 - uv.y;

    float iTime = ubuf.time * 0.15;

    float snow = 0.0;

    for (int k = 0; k < 6; k++) {
        for (int i = 0; i < 12; i++) {
            float cellSize = 2.0 + (float(i) * 3.0);
            float downSpeed = 0.3 + (sin(iTime * 0.4 + float(k + i * 20)) + 1.0) * 0.00008;

            vec2 uvAnim = uv + vec2(
                0.01 * sin((iTime + float(k * 6185)) * 0.6 + float(i)) * (5.0 / float(i + 1)),
                downSpeed * (iTime + float(k * 1352)) * (1.0 / float(i + 1))
            );

            vec2 uvStep = (ceil((uvAnim) * cellSize - vec2(0.5, 0.5)) / cellSize);
            float x = fract(sin(dot(uvStep.xy, vec2(12.9898 + float(k) * 12.0, 78.233 + float(k) * 315.156))) * 43758.5453 + float(k) * 12.0) - 0.5;
            float y = fract(sin(dot(uvStep.xy, vec2(62.2364 + float(k) * 23.0, 94.674 + float(k) * 95.0))) * 62159.8432 + float(k) * 12.0) - 0.5;

            float randomMagnitude1 = sin(iTime * 2.5) * 0.7 / cellSize;
            float randomMagnitude2 = cos(iTime * 1.65) * 0.7 / cellSize;

            float d = 5.0 * distance((uvStep.xy + vec2(x * sin(y), y) * randomMagnitude1 + vec2(y, x) * randomMagnitude2), uvAnim.xy);

            float omiVal = fract(sin(dot(uvStep.xy, vec2(32.4691, 94.615))) * 31572.1684);
            if (omiVal < 0.03) {
                float newd = (x + 1.0) * 0.4 * clamp(1.9 - d * (15.0 + (x * 6.3)) * (cellSize / 1.4), 0.0, 1.0);
                snow += newd;
            }
        }
    }

    // Blend white snow over background color
    float snowAlpha = clamp(snow * 2.0, 0.0, 1.0);
    vec3 snowColor = vec3(1.0);
    vec3 blended = mix(ubuf.bgColor.rgb, snowColor, snowAlpha);

    // Apply rounded corner mask
    vec2 pixelPos = qt_TexCoord0 * vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 center = pixelPos - vec2(ubuf.itemWidth, ubuf.itemHeight) * 0.5;
    vec2 halfSize = vec2(ubuf.itemWidth, ubuf.itemHeight) * 0.5;
    float dist = roundedBoxSDF(center, halfSize, ubuf.cornerRadius);
    float cornerMask = 1.0 - smoothstep(-1.0, 0.0, dist);

    // Output with premultiplied alpha
    float finalAlpha = ubuf.qt_Opacity * cornerMask;
    fragColor = vec4(blended * finalAlpha, finalAlpha);
}
