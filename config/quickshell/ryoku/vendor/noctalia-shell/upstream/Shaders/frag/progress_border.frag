#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float borderWidth;
    vec4 progressColor;
    vec4 borderColor;
    vec4 backgroundColor;
    float borderRadius;
} ubuf;

void main() {
    vec2 coord = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);

    if (ubuf.borderRadius > 0.0) {
        // Circular progress
        vec2 center = vec2(0.5, 0.5);
        vec2 dir = coord - center;
        float dist = length(dir);

        float outerRadius = 0.5;
        float innerRadius = outerRadius - ubuf.borderWidth;

        float angle = atan(dir.y, dir.x) + radians(90.0);
        if (angle < 0.0) angle += radians(360.0);
        float maxAngle = radians(360.0) * p;

        bool inBorder = dist >= innerRadius && dist <= outerRadius;
        bool inProgress = inBorder && angle <= maxAngle;

        if (inProgress) {
            fragColor = ubuf.progressColor * ubuf.qt_Opacity;
        } else if (inBorder) {
            fragColor = ubuf.borderColor * ubuf.qt_Opacity;
        } else if (dist < innerRadius) {
            fragColor = ubuf.backgroundColor * ubuf.qt_Opacity;
        } else {
            fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        }
    } else {
        // Rectangular progress
        bool inBorder =
            coord.x < ubuf.borderWidth ||
            coord.x > (1.0 - ubuf.borderWidth) ||
            coord.y < ubuf.borderWidth ||
            coord.y > (1.0 - ubuf.borderWidth);

        float progressPos = p;
        bool inProgress = inBorder && coord.x <= progressPos;

        if (inProgress) {
            fragColor = ubuf.progressColor * ubuf.qt_Opacity;
        } else if (inBorder) {
            fragColor = ubuf.borderColor * ubuf.qt_Opacity;
        } else {
            fragColor = ubuf.backgroundColor * ubuf.qt_Opacity;
        }
    }
}