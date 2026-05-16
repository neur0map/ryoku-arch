#!/bin/bash

MIGRATION_ID="024-display-output-persistence"
MIGRATION_TITLE="Persist Niri display output settings"
MIGRATION_DESCRIPTION="Moves monitor output blocks into config.d/15-outputs.kdl and includes that file so refresh rates survive boot and update."
# shellcheck disable=SC2088
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local niri_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
  local root_config="$niri_dir/config.kdl"
  local outputs_file="$niri_dir/config.d/15-outputs.kdl"

  [[ -f $root_config ]] || return 1
  [[ -f $outputs_file ]] || return 0
  grep -Eq '^[[:space:]]*include[[:space:]]+"config\.d/15-outputs\.kdl"[[:space:]]*$' "$root_config" || return 0
  grep -Eq '^[[:space:]]*output[[:space:]]+"[^"]+"[[:space:]]*\{' "$root_config" && return 0
  return 1
}

migration_preview() {
  echo -e "${STY_RED}- display output blocks stored in ~/.config/niri/config.kdl${STY_RST}"
  echo -e "${STY_GREEN}+ display output blocks stored in ~/.config/niri/config.d/15-outputs.kdl${STY_RST}"
  echo -e "${STY_GREEN}+ root Niri config includes config.d/15-outputs.kdl${STY_RST}"
}

migration_apply() {
  local niri_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
  local root_config="$niri_dir/config.kdl"
  local outputs_file="$niri_dir/config.d/15-outputs.kdl"
  local default_outputs="${REPO_ROOT}/defaults/niri/config.d/15-outputs.kdl"

  mkdir -p "$niri_dir/config.d"

  if [[ ! -f $outputs_file ]]; then
    if [[ -f $default_outputs ]]; then
      cp -f "$default_outputs" "$outputs_file"
    else
      : >"$outputs_file"
    fi
  fi

  [[ -f $root_config ]] || return 0

  RYOKU_NIRI_ROOT_CONFIG="$root_config" \
  RYOKU_NIRI_OUTPUTS_FILE="$outputs_file" \
    python3 <<'PY'
from pathlib import Path
import os
import re

root_path = Path(os.environ["RYOKU_NIRI_ROOT_CONFIG"])
outputs_path = Path(os.environ["RYOKU_NIRI_OUTPUTS_FILE"])
include_line = 'include "config.d/15-outputs.kdl"'

text = root_path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
new_lines = []
moved_blocks = []
i = 0

while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    if re.match(r'^include\s+"config\.d/15-outputs\.kdl"\s*$', stripped):
        i += 1
        continue

    if re.match(r'^output\s+"[^"]+"\s*\{', stripped):
        block = [line]
        depth = line.count("{") - line.count("}")
        i += 1
        while i < len(lines) and depth > 0:
            block.append(lines[i])
            depth += lines[i].count("{") - lines[i].count("}")
            i += 1
        moved_blocks.append("".join(block).strip("\n"))
        continue

    new_lines.append(line)
    i += 1

inserted = False
insert_after = r'^\s*include\s+"config\.d/10-input-and-cursor\.kdl"\s*$'
insert_before_candidates = [
    r'^\s*include\s+"config\.d/20-layout-and-overview\.kdl"\s*$',
    r'^\s*include\s+"config\.d/90-user-extra\.kdl"\s*$',
]

for index, line in enumerate(new_lines):
    if re.match(insert_after, line):
        new_lines.insert(index + 1, include_line + "\n")
        inserted = True
        break

if not inserted:
    for pattern in insert_before_candidates:
        for index, line in enumerate(new_lines):
            if re.match(pattern, line):
                new_lines.insert(index, include_line + "\n")
                inserted = True
                break
        if inserted:
            break

if not inserted:
    if new_lines and not new_lines[-1].endswith("\n"):
        new_lines[-1] += "\n"
    if new_lines and "".join(new_lines).strip():
        new_lines.append("\n")
    new_lines.append(include_line + "\n")

root_path.write_text("".join(new_lines).rstrip() + "\n", encoding="utf-8")

if moved_blocks:
    outputs_text = outputs_path.read_text(encoding="utf-8") if outputs_path.exists() else ""
    existing_names = set(
        re.findall(r'^\s*output\s+"([^"]+)"\s*\{', outputs_text, re.MULTILINE)
    )
    append_blocks = []

    for block in moved_blocks:
        match = re.search(r'^\s*output\s+"([^"]+)"\s*\{', block, re.MULTILINE)
        if not match:
            continue
        output_name = match.group(1)
        if output_name in existing_names:
            continue
        append_blocks.append(block.rstrip())
        existing_names.add(output_name)

    if append_blocks:
        new_outputs = outputs_text.rstrip()
        if new_outputs:
            new_outputs += "\n\n"
        new_outputs += "\n\n".join(append_blocks) + "\n"
        outputs_path.write_text(new_outputs, encoding="utf-8")
PY

  if command -v niri >/dev/null 2>&1; then
    niri msg action load-config-file >/dev/null 2>&1 || true
  fi
}
