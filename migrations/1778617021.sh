echo "Install Helium and switch default browser settings"

if ! ryoku-install-helium-browser; then
  echo "Helium could not be installed automatically; keeping existing browser settings"
  exit 0
fi

xdg-settings set default-web-browser helium.desktop 2>/dev/null || true
for mime in x-scheme-handler/http x-scheme-handler/https x-scheme-handler/mailto text/html text/xml application/xhtml+xml; do
  xdg-mime default helium.desktop "$mime" 2>/dev/null || true
done

update_shell_config() {
  local config_file="$1"
  local tmp_file

  [[ -f $config_file ]] || return 0
  ryoku-cmd-present jq || return 0

  tmp_file="$(mktemp)"
  if jq '
    def old_browser:
      . == "firefox"
      or . == "chromium"
      or . == "/usr/bin/firefox"
      or . == "/usr/bin/chromium";

    if ((.apps.browser? // "") | old_browser) or ((.apps.browser? // "") == "") then
      .apps.browser = "helium"
    else
      .
    end
    | if (.dock.pinnedApps? // []) == ["org.gnome.Nautilus", "firefox", "foot"]
        or (.dock.pinnedApps? // []) == ["org.gnome.Nautilus", "firefox", "kitty"]
        or (.dock.pinnedApps? // []) == ["org.gnome.Nautilus", "chromium", "kitty"] then
        .dock.pinnedApps = ["org.gnome.Nautilus", "helium", "kitty"]
      else
        .
      end
    | if (.sidebar.widgets.quickLaunch? | type) == "array" then
        .sidebar.widgets.quickLaunch |= map(
          if (.name == "Browser" and ((.cmd // "") | old_browser)) then
            .cmd = "helium"
          else
            .
          end
        )
      else
        .
      end
  ' "$config_file" > "$tmp_file"; then
    mv "$tmp_file" "$config_file"
  else
    rm -f "$tmp_file"
  fi
}

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
update_shell_config "$CONFIG_HOME/ryoku-shell/config.json"
update_shell_config "$CONFIG_HOME/illogical-impulse/config.json"
