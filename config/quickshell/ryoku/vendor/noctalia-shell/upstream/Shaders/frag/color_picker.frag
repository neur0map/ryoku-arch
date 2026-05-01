#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf
{
    mat4 qt_Matrix;
    vec4 params; // x=opacity, y=fixedVal, z=mode, w=padding
};

// Compatibility function for GLSL ES to avoid % operator issues
int mod_compat(float a, float b) {
    return int(a - floor(a / b) * b);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main()
{
    float x = qt_TexCoord0.x;
    float y = 1.0 - qt_TexCoord0.y; // Flip Y direction

    // Unpack vector
    float opacity = params.x;
    float fixedVal = params.y;
    float mode = params.z + 0.1; // +0.1 safely handles float rounding

    // Build permutation matrices for swizzling
    vec3 base = vec3(x, y, fixedVal);

    // Determine Mode Logic
    // 0: (Red/Hue) 1: (Green/Sat) 2: (Blue/Val)
    int perm = mod_compat(mode, 3.0);

    float isHSV = step(3.0, mode);

    // Branchless Selection
    vec3 mask = vec3(
        float(perm == 0),
        float(perm == 1),
        float(perm == 2));

    // Swizzle fo shizzle
    // If perm 0: base.zxy -> (fixedVal, x, y)
    // If perm 1: base.xzy -> (x, fixedVal, y)
    // If perm 2: base.xyz -> (x, y, fixedVal)
    vec3 rgb_base = (base.zxy * mask.x) + (base.xzy * mask.y) + (base.xyz * mask.z);

    // Final mix
    vec3 finalColor = mix(rgb_base, hsv2rgb(rgb_base), isHSV);

    fragColor = vec4(finalColor, 1.0) * opacity;
}
