#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_terminal_wrapper_prefers_configured_terminal_and_maps_flags() {
  local temp_dir home_dir config_dir bin_dir app_dir log_file output status

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  config_dir="$home_dir/.config"
  bin_dir="$temp_dir/bin"
  app_dir="$home_dir/.local/share/applications"
  log_file="$temp_dir/alacritty.log"
  status=0

  mkdir -p "$config_dir" "$bin_dir" "$app_dir"

  cat > "$config_dir/xdg-terminals.list" <<'EOF'
Alacritty.desktop
EOF

  cat > "$app_dir/Alacritty.desktop" <<'EOF'
[Desktop Entry]
Type=Application
TryExec=alacritty
Exec=alacritty
X-TerminalArgExec=-e
X-TerminalArgAppId=--class=
X-TerminalArgTitle=--title=
X-TerminalArgDir=--working-directory=
EOF

  cat > "$bin_dir/alacritty" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$ALACRITTY_LOG_FILE"
EOF

  chmod +x "$bin_dir/alacritty"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    ALACRITTY_LOG_FILE="$log_file" \
    /bin/bash "$ROOT_DIR/bin/ryoku-terminal-exec" \
      --app-id=org.ryoku.terminal \
      --title=Ryoku \
      --dir=/tmp/demo \
      bash -lc "echo hi" >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "ryoku-terminal-exec should launch the configured terminal (status=$status)"
  fi

  output=$(<"$log_file")
  [[ $output == *"--class=org.ryoku.terminal"* ]] || {
    rm -rf "$temp_dir"
    fail "ryoku-terminal-exec should map app-id for Alacritty"
  }
  [[ $output == *"--title=Ryoku"* ]] || {
    rm -rf "$temp_dir"
    fail "ryoku-terminal-exec should map title for Alacritty"
  }
  [[ $output == *"--working-directory=/tmp/demo"* ]] || {
    rm -rf "$temp_dir"
    fail "ryoku-terminal-exec should map working directory for Alacritty"
  }
  [[ $output == *"-e bash -lc echo hi"* ]] || {
    rm -rf "$temp_dir"
    fail "ryoku-terminal-exec should pass the command via the terminal exec argument"
  }

  rm -rf "$temp_dir"
}

assert_launcher_commands_use_ryoku_shell_and_fuzzel() {
  grep -q 'ryoku-shell overview toggle' "$ROOT_DIR/bin/ryoku-launch-drun" \
    || fail "ryoku-launch-drun should open the Ryoku overview launcher"
  grep -q 'fuzzel --dmenu' "$ROOT_DIR/bin/ryoku-launch-drun" \
    || fail "ryoku-launch-drun --dmenu should use fuzzel dmenu mode"
  grep -q 'ryoku-shell clipboard toggle' "$ROOT_DIR/bin/ryoku-launch-clipboard" \
    || fail "ryoku-launch-clipboard should open Ryoku clipboard"
  [[ ! -e $ROOT_DIR/bin/tofi ]] || fail "bin/tofi should not be installed by Ryoku"
  [[ ! -e $ROOT_DIR/bin/tofi-drun ]] || fail "bin/tofi-drun should not be installed by Ryoku"
}

assert_shell_app_launchers_use_terminal_aware_launch_utils() {
  local launch_utils="$ROOT_DIR/shell/modules/common/functions/LaunchUtils.qml"
  local bar_button="$ROOT_DIR/shell/modules/bar/BarTaskbarButton.qml"
  local dock_button="$ROOT_DIR/shell/modules/dock/DockAppButton.qml"
  local notifications="$ROOT_DIR/shell/services/Notifications.qml"

  grep -q 'function launchDesktopEntry(entry)' "$launch_utils" \
    || fail "LaunchUtils should expose terminal-aware desktop entry launching"
  grep -q 'function launchByDesktopId(desktopId)' "$launch_utils" \
    || fail "LaunchUtils should expose centralized desktop-id launching"
  grep -q '/usr/bin/gtk-launch' "$launch_utils" \
    || fail "LaunchUtils should launch desktop entries through gtk-launch"

  grep -q 'LaunchUtils.launchDesktopEntry(root.desktopEntry)' "$bar_button" \
    || fail "bar taskbar should use LaunchUtils for desktop entries"
  grep -q 'LaunchUtils.launchByDesktopId(id)' "$bar_button" \
    || fail "bar taskbar should use LaunchUtils for app-id fallback launches"
  grep -q 'LaunchUtils.launchDesktopEntry(root.desktopEntry)' "$dock_button" \
    || fail "dock should use LaunchUtils for desktop entries"
  grep -q 'LaunchUtils.launchByDesktopId(id)' "$dock_button" \
    || fail "dock should use LaunchUtils for app-id fallback launches"
  grep -q 'LaunchUtils.launchByDesktopId(appIcon)' "$notifications" \
    || fail "notification view actions should use centralized desktop-id launching"

  if grep -Eq 'const cmd = "/usr/bin/gtk-launch' "$bar_button" "$dock_button" "$notifications"; then
    fail "shell app launchers should not keep ad hoc gtk-launch shell snippets"
  fi
}

assert_terminal_wrapper_prefers_configured_terminal_and_maps_flags
assert_launcher_commands_use_ryoku_shell_and_fuzzel
assert_shell_app_launchers_use_terminal_aware_launch_utils

echo "PASS: terminal and launcher wrapper tests"
