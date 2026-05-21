echo "Remove global Niri app-window opacity from glass defaults"

rules_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/30-window-rules.kdl"

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


def has_match(block):
    return bool(re.search(r"^\s*match\b", block, flags=re.MULTILINE))


def remove_opacity(block):
    return re.sub(r"^\s*opacity\s+[\d.]+\n?", "", block, flags=re.MULTILINE)


chunks = []
cursor = 0
changed = False

for outer_start, inner_start, inner_end, outer_end, block in iter_window_rules(text):
    chunks.append(text[cursor:inner_start])
    if not has_match(block) and re.search(
        r"^\s*background-effect\s*\{", block, flags=re.MULTILINE
    ):
        repaired = remove_opacity(block)
        changed = changed or repaired != block
        chunks.append(repaired)
    else:
        chunks.append(block)
    cursor = inner_end

chunks.append(text[cursor:])

if changed:
    path.write_text("".join(chunks).rstrip() + "\n", encoding="utf-8")
PY
fi

niri msg action load-config-file >/dev/null 2>&1 || true
