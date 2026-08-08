
// The accent a record wears. Album art is data, not chrome (docs/ui-ux.md), so a
// music surface tints from the sleeve rather than the theme: pick the most
// vibrant tone a ColorQuantizer found, then lift it to a vivid, readable version
// of itself, because a dark or muddy sleeve would otherwise hand back an accent
// that disappears against the card. Shared by every player surface so they agree
// on one colour per song.

function vibrance(c) {
    var mx = Math.max(c.r, c.g, c.b);
    var mn = Math.min(c.r, c.g, c.b);
    return (mx > 0 ? (mx - mn) / mx : 0) * mx;
}

// colors: the quantizer's palette. fallback: the theme accent for art-less
// tracks and sleeves with no colour worth taking.
function accentOf(colors, fallback) {
    var list = colors || [];
    var best = fallback;
    var score = 0.10;
    for (var i = 0; i < list.length; i++) {
        var v = vibrance(list[i]);
        if (v > score) {
            score = v;
            best = list[i];
        }
    }
    return Qt.hsla(best.hslHue,
                   Math.max(0.5, best.hslSaturation),
                   Math.max(0.52, Math.min(0.68, best.hslLightness)),
                   1);
}

// The card plate a record wears: the theme surface nudged a tenth toward the
// sleeve's accent, held near-opaque so text stays legible. Shared so the card,
// the lyric edge-fades and any wash agree on one tone per song.
function plateOf(accent, surface) {
    return Qt.rgba(
        surface.r + (accent.r - surface.r) * 0.10,
        surface.g + (accent.g - surface.g) * 0.10,
        surface.b + (accent.b - surface.b) * 0.10,
        0.90);
}
