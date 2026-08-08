.pragma library

// WANTED maps Ryoku's colors.json keys onto this shell's semantic slots. Ryoku's
// theme daemon rewrites ~/.cache/ryoku/colors.json on every wallpaper change with
// the sixteen terminal colours (color0..color15) plus the Material roles, so the
// same colorN keys HANCORE's Rise read from Ryoku's colors.toml are present here
// verbatim; only the file format (JSON) and the accent source (Material primary)
// differ. Everything downstream is unchanged.
const WANTED = [
    { target: "paper",      keys: ["background", "bg"] },
    { target: "ink",        keys: ["foreground", "fg"] },
    { target: "color01",    keys: ["color1", "red"] },
    { target: "color02",    keys: ["color2", "green"] },
    { target: "color03",    keys: ["color3", "yellow"] },
    { target: "color04",    keys: ["color4", "blue"] },
    { target: "color05",    keys: ["color5", "magenta"] },
    { target: "color06",    keys: ["color6", "cyan"] },
    { target: "color07",    keys: ["color7", "bright_fg", "light_fg"] },
    { target: "sumi",       keys: ["color8", "muted", "dark_fg"] },
    { target: "accentHint", keys: ["accent", "primary"] },
];

function parseAll(text) {
    const out = {};
    if (!text) return out;
    try {
        const raw = JSON.parse(text);
        if (raw && typeof raw === "object")
            for (const k in raw) out[String(k).toLowerCase()] = raw[k];
    } catch (e) {}
    return out;
}

function mapKeys(raw) {
    const out = {};
    if (!raw) return out;
    for (let i = 0; i < WANTED.length; i++) {
        const group = WANTED[i];
        for (let j = 0; j < group.keys.length; j++) {
            const value = raw[group.keys[j]];
            if (validColor(value)) {
                out[group.target] = value;
                break;
            }
        }
    }
    return out;
}

function parse(text) {
    return mapKeys(parseAll(text));
}

function validColor(value) {
    return typeof value === "string" && /^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(value);
}

function setColor(theme, key, value) {
    if (validColor(value)) theme[key] = value;
}

// Write a parsed palette onto a Theme.qml instance. Missing slots are left at
// their current value so a partial or malformed palette never blanks the live
// theme. Ryoku colors.json values are #RRGGBB; #RRGGBBAA is accepted too.
function apply(theme, palette) {
    if (!palette) return;
    setColor(theme, "paper",      palette.paper);
    setColor(theme, "ink",        palette.ink);
    setColor(theme, "sumi",       palette.sumi);
    setColor(theme, "color01",    palette.color01);
    setColor(theme, "color02",    palette.color02);
    setColor(theme, "color03",    palette.color03);
    setColor(theme, "color04",    palette.color04);
    setColor(theme, "color05",    palette.color05);
    setColor(theme, "color06",    palette.color06);
    setColor(theme, "color07",    palette.color07);
    setColor(theme, "accentHint", palette.accentHint);
}
