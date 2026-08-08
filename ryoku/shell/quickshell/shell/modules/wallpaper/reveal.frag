#version 440

// Wallpaper reveal shader for the in-shell backdrop. Reveals newTex over oldTex
// through an animated per-pixel mask whose geometry is `kind`, whose feathered
// boundary width is `edgeSoftness`, and whose progress is already eased by the
// preset's cubic-bezier on the QML side. This restores the wallpaper-daemon
// transition set (fade / wipe / wave / center / grow / any / outer) on the GPU:
// the new image reveals over the old via the mask, fade is a plain eased
// crossfade, and both textures are the current + incoming buffers so an
// interrupted reveal commits and the next one grows from that composite.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // eased 0..1 sweep of the reveal front
    float angle;        // wipe / wave sweep direction, degrees
    float waveAmp;      // wave boundary amplitude (fraction of the sweep extent)
    float originX;      // radial origin, surface coords 0..1
    float originY;
    float edgeSoftness; // feathered boundary half-width (fraction)
    int kind;           // 0 fade,1 wipe,2 wave,3 center,4 grow,5 any,6 outer
    vec2 res;           // surface size in px, for aspect-correct circles
};

layout(binding = 1) uniform sampler2D oldTex;
layout(binding = 2) uniform sampler2D newTex;

const float TAU = 6.28318530718;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 oldC = texture(oldTex, uv);
    vec4 newC = texture(newTex, uv);

    float a;
    if (kind == 0) {
        // fade: plain eased crossfade, no spatial mask.
        a = progress;
    } else {
        float pos; // 0 = revealed first, 1 = revealed last
        if (kind == 1 || kind == 2) {
            // wipe / wave: project uv onto the sweep direction and normalise to the
            // unit square's projected extent, so the front sweeps fully edge to edge
            // at any angle.
            float rad = radians(angle);
            vec2 dir = vec2(cos(rad), sin(rad));
            float lo = min(0.0, dir.x) + min(0.0, dir.y);
            float hi = max(0.0, dir.x) + max(0.0, dir.y);
            pos = (dot(uv, dir) - lo) / max(hi - lo, 1e-4);
            if (kind == 2) {
                // wave: ripple the boundary with a sine along the perpendicular axis.
                vec2 perp = vec2(-dir.y, dir.x);
                pos += waveAmp * sin(dot(uv, perp) * TAU * 2.5);
            }
        } else {
            // radial kinds: distance from the origin in aspect-corrected space so the
            // reveal front is a true circle, normalised by the farthest corner.
            float asp = res.x / max(res.y, 1.0);
            vec2 o = vec2(originX * asp, originY);
            vec2 p = vec2(uv.x * asp, uv.y);
            float d = distance(p, o);
            float m = max(max(distance(o, vec2(0.0, 0.0)), distance(o, vec2(asp, 0.0))),
                          max(distance(o, vec2(0.0, 1.0)), distance(o, vec2(asp, 1.0))));
            float radial = d / max(m, 1e-4);
            // center / grow / any bloom outward; outer seals inward from the edges.
            pos = (kind == 6) ? (1.0 - radial) : radial;
        }
        // sweep a feathered front; widen the range by the feather (and any wave
        // amplitude) so progress 0 reveals nothing and progress 1 reveals all.
        float soft = max(edgeSoftness, 0.002);
        float margin = soft + waveAmp;
        float f = progress * (1.0 + 2.0 * margin) - margin;
        a = smoothstep(pos - soft, pos + soft, f);
    }

    fragColor = mix(oldC, newC, clamp(a, 0.0, 1.0)) * qt_Opacity;
}
