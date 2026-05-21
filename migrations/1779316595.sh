echo "Enable global Niri window glass at 70 percent"

niri_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
layout_file="$niri_dir/config.d/20-layout-and-overview.kdl"
rules_file="$niri_dir/config.d/30-window-rules.kdl"
default_layout="$RYOKU_PATH/config/niri/config.d/20-layout-and-overview.kdl"
default_rules="$RYOKU_PATH/config/niri/config.d/30-window-rules.kdl"

mkdir -p "$niri_dir/config.d"

if [[ ! -f $layout_file && -f $default_layout ]]; then
  cp "$default_layout" "$layout_file"
fi

if [[ ! -f $rules_file && -f $default_rules ]]; then
  cp "$default_rules" "$rules_file"
fi

if [[ -f $layout_file ]]; then
  python3 - "$layout_file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")


def find_block(content, name):
    pattern = re.compile(rf"(?:^|\n)\s*{re.escape(name)}\s*\{{")
    match = pattern.search(content)
    if not match:
        return None

    inner_start = match.end()
    depth = 1
    i = inner_start
    while i < len(content) and depth > 0:
        if content[i] == "{":
            depth += 1
        elif content[i] == "}":
            depth -= 1
        i += 1

    if depth != 0:
        return None
    return match.start(), inner_start, i - 1, i, content[inner_start : i - 1]


def set_line(block, key, value):
    pattern = rf"(^\s*{re.escape(key)}\s+)[^\n]+"
    if re.search(pattern, block, flags=re.MULTILINE):
        return re.sub(pattern, rf"\g<1>{value}", block, count=1, flags=re.MULTILINE)
    return block.rstrip() + f"\n    {key} {value}\n"


blur = find_block(text, "blur")
if blur:
    outer_start, inner_start, inner_end, outer_end, block = blur
    block = set_line(block, "passes", "2")
    block = set_line(block, "offset", "3.0")
    block = set_line(block, "noise", "0.03")
    block = set_line(block, "saturation", "1.0")
    text = text[:inner_start] + block + text[inner_end:]
    text = re.sub(
        r"// .*background blur tuning\.\n(\s*blur\s*\{)",
        "// Global wallpaper blur used by window background effects.\n\\1",
        text,
        count=1,
    )
else:
    block = (
        "\n\n"
        "// Global wallpaper blur used by window background effects.\n"
        "blur {\n"
        "    passes 2\n"
        "    offset 3.0\n"
        "    noise 0.03\n"
        "    saturation 1.0\n"
        "}\n"
    )
    overview = re.search(r"(?:^|\n)\s*overview\s*\{", text)
    if overview:
        text = text[: overview.start()] + block + text[overview.start() :]
    else:
        text = text.rstrip() + block

path.write_text(text.rstrip() + "\n", encoding="utf-8")
PY
fi

if [[ -f $rules_file ]]; then
  python3 - "$rules_file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")


def iter_window_rules(content):
    pattern = re.compile(r"(?:^|\n)\s*window-rule\s*\{")
    for match in pattern.finditer(content):
        inner_start = match.end()
        depth = 1
        i = inner_start
        while i < len(content) and depth > 0:
            if content[i] == "{":
                depth += 1
            elif content[i] == "}":
                depth -= 1
            i += 1
        if depth == 0:
            yield match.start(), inner_start, i - 1, i, content[inner_start : i - 1]


def find_named_block(block, name):
    pattern = re.compile(rf"(?:^|\n)\s*{re.escape(name)}\s*\{{")
    match = pattern.search(block)
    if not match:
        return None
    inner_start = match.end()
    depth = 1
    i = inner_start
    while i < len(block) and depth > 0:
        if block[i] == "{":
            depth += 1
        elif block[i] == "}":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return match.start(), inner_start, i - 1, i, block[inner_start : i - 1]


def has_match(block):
    return bool(re.search(r"^\s*match\b", block, flags=re.MULTILINE))


def set_line(block, key, value, indent="    "):
    pattern = rf"(^\s*{re.escape(key)}\s+)[^\n]+"
    if re.search(pattern, block, flags=re.MULTILINE):
        return re.sub(pattern, rf"\g<1>{value}", block, count=1, flags=re.MULTILINE)
    return f"\n{indent}{key} {value}\n" + block.lstrip("\n")


def ensure_background_effect(block):
    effect = find_named_block(block, "background-effect")
    if effect:
        outer_start, inner_start, inner_end, outer_end, effect_block = effect
        effect_block = set_line(effect_block, "blur", "true", indent="        ")
        effect_block = set_line(effect_block, "xray", "false", indent="        ")
        effect_block = set_line(effect_block, "noise", "0.03", indent="        ")
        effect_block = set_line(effect_block, "saturation", "1.0", indent="        ")
        return block[:inner_start] + effect_block + block[inner_end:]

    effect_block = (
        "\n"
        "    background-effect {\n"
        "        blur true\n"
        "        xray false\n"
        "        noise 0.03\n"
        "        saturation 1.0\n"
        "    }\n"
    )
    return block.rstrip() + "\n" + effect_block


glass_rule = None
first_rule_end = None
for outer_start, inner_start, inner_end, outer_end, block in iter_window_rules(text):
    if first_rule_end is None:
        first_rule_end = outer_end
    if has_match(block):
        continue
    if re.search(r"^\s*opacity\s+[\d.]+", block, flags=re.MULTILINE) or re.search(
        r"^\s*background-effect\s*\{", block, flags=re.MULTILINE
    ):
        glass_rule = (inner_start, inner_end, block)
        break

if glass_rule:
    inner_start, inner_end, block = glass_rule
    block = set_line(block, "opacity", "0.70")
    block = ensure_background_effect(block)
    text = text[:inner_start] + block + text[inner_end:]
else:
    block = (
        "\n\n"
        "// Global window glass: keep opened windows translucent over the wallpaper.\n"
        "window-rule {\n"
        "    opacity 0.70\n"
        "\n"
        "    background-effect {\n"
        "        blur true\n"
        "        xray false\n"
        "        noise 0.03\n"
        "        saturation 1.0\n"
        "    }\n"
        "}\n"
    )
    if first_rule_end is not None:
        text = text[:first_rule_end] + block + text[first_rule_end:]
    else:
        text = text.rstrip() + block

text = re.sub(
    r"(match\s+is-active\s*=\s*false\s*\n\s*opacity\s+)[\d.]+",
    r"\g<1>0.70",
    text,
    count=1,
)

path.write_text(text.rstrip() + "\n", encoding="utf-8")
PY
fi

niri msg action load-config-file >/dev/null 2>&1 || true
