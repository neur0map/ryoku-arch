#!/bin/bash

# Format-aware helpers for editing the user's Hyprland config.
#
# Hyprland 0.55+ loads ~/.config/hypr/hyprland.lua (Lua) INSTEAD of hyprland.conf
# (hyprlang) when the .lua file is present (decided once at startup). Ryoku ships the
# Lua config; these helpers let ryoku-* tools read/write env vars and ensure module
# loads without each tool re-implementing the lua-vs-hyprlang sed/awk. A hyprlang
# branch is kept so tools still work on an unmigrated (.conf-only) box.

hypr_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
}

# True when Hyprland would load the Lua config (hyprland.lua present).
hypr_is_lua() {
  [[ -f "$(hypr_dir)/hyprland.lua" ]]
}

# Path of the config Hyprland actually loads (Lua wins, mirroring Hyprland).
hypr_entrypoint() {
  local d
  d="$(hypr_dir)"
  if [[ -f "$d/hyprland.lua" ]]; then
    printf '%s\n' "$d/hyprland.lua"
  else
    printf '%s\n' "$d/hyprland.conf"
  fi
}

# Upsert an env var in a hypr config FILE, picking syntax from its extension.
#   hypr_set_env <file> <KEY> <VALUE>
# Lua:      hl.env("KEY", "VALUE")
# Hyprlang: env = KEY,VALUE
# Values here are simple (cursor names, driver names, integers, DRM paths) so no sed
# metacharacter escaping is needed; keep it that way for callers.
hypr_set_env() {
  local file="$1" key="$2" value="$3"
  [[ -f $file ]] || return 0
  if [[ $file == *.lua ]]; then
    if grep -qE "^[[:space:]]*hl\.env\(\"$key\"," "$file"; then
      sed -i -E "s|^[[:space:]]*hl\.env\(\"$key\",.*|hl.env(\"$key\", \"$value\")|" "$file"
    else
      printf 'hl.env("%s", "%s")\n' "$key" "$value" >>"$file"
    fi
  else
    if grep -qE "^[[:space:]]*env[[:space:]]*=[[:space:]]*$key," "$file"; then
      sed -i "s|^[[:space:]]*env[[:space:]]*=[[:space:]]*$key,.*|env = $key,$value|" "$file"
    else
      printf 'env = %s,%s\n' "$key" "$value" >>"$file"
    fi
  fi
}

# Read an env var value from a hypr config FILE (echoes the value, or nothing).
#   hypr_get_env <file> <KEY>
hypr_get_env() {
  local file="$1" key="$2"
  [[ -f $file ]] || return 0
  if [[ $file == *.lua ]]; then
    sed -n -E "s|^[[:space:]]*hl\.env\(\"$key\",[[:space:]]*\"([^\"]*)\"\).*|\1|p" "$file" | tail -1
  else
    sed -n "s/^[[:space:]]*env[[:space:]]*=[[:space:]]*$key,\(.*\)$/\1/p" "$file" | tail -1
  fi
}

# Ensure the Lua entrypoint require()s MODULE, inserted just before require("custom")
# (so user overrides still win) or appended if there is no custom require. Idempotent.
#   hypr_ensure_require <hyprland.lua> <module>
hypr_ensure_require() {
  local entry="$1" module="$2" tmp
  [[ -f $entry ]] || return 0
  grep -qE "^[[:space:]]*require\(\"$module\"\)" "$entry" && return 0
  tmp="$(mktemp)"
  awk -v m="$module" '
    !done && /^[[:space:]]*require\("custom"\)/ { print "require(\"" m "\")"; done = 1 }
    { print }
    END { if (!done) print "require(\"" m "\")" }
  ' "$entry" >"$tmp" && cat "$tmp" >"$entry"
  rm -f "$tmp"
}
