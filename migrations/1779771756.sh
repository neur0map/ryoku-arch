echo "Use Nautilus for shell folder actions"

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"
legacy_config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell/config.json"

update_typed_config() {
  local file="$1"
  local temp_file

  if ryoku-cmd-missing jq; then
    return 0
  fi

  mkdir -p "$(dirname "$file")"
  [[ -f $file ]] || printf '{}\n' >"$file"

  temp_file="$(mktemp)"
  if jq '
    if ((.general.apps.explorer? // []) == [] or (.general.apps.explorer? // []) == ["thunar"] or (.general.apps.explorer? // "") == "thunar") then
      .general = (.general // {})
      | .general.apps = (.general.apps // {})
      | .general.apps.explorer = ["nautilus"]
    else
      .
    end
  ' "$file" >"$temp_file"; then
    mv "$temp_file" "$file"
  else
    rm -f "$temp_file"
  fi
}

update_legacy_config() {
  local file="$1"
  local temp_file

  if ryoku-cmd-missing jq || [[ ! -f $file ]]; then
    return 0
  fi

  temp_file="$(mktemp)"
  if jq '
    if ((.apps.explorer? // "") == "thunar") then
      .apps.explorer = "nautilus"
    else
      .
    end
  ' "$file" >"$temp_file"; then
    mv "$temp_file" "$file"
  else
    rm -f "$temp_file"
  fi
}

update_typed_config "$config_file"
update_legacy_config "$legacy_config_file"

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
