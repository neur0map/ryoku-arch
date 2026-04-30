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

assert_tofi_wrappers_fall_back_to_fuzzel() {
  local temp_dir home_dir bin_dir log_file output status

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  log_file="$temp_dir/fuzzel.log"
  status=0

  mkdir -p "$home_dir" "$bin_dir"

  cat > "$bin_dir/fuzzel" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$FUZZEL_LOG_FILE"
EOF

  chmod +x "$bin_dir/fuzzel"

  printf 'one\ntwo\n' | HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    FUZZEL_LOG_FILE="$log_file" \
    /bin/bash "$ROOT_DIR/bin/tofi" --config /tmp/ignored --prompt-text "Pick: " >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "tofi wrapper should fall back to fuzzel (status=$status)"
  fi

  output=$(<"$log_file")
  [[ $output == *"--dmenu"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi wrapper should invoke fuzzel in dmenu mode"
  }
  [[ $output == *"--namespace=tofi"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi wrapper should preserve the tofi namespace"
  }
  [[ $output == *"--prompt=Pick: "* ]] || {
    rm -rf "$temp_dir"
    fail "tofi wrapper should map prompt-text to fuzzel prompt"
  }

  : > "$log_file"
  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    FUZZEL_LOG_FILE="$log_file" \
    /bin/bash "$ROOT_DIR/bin/tofi-drun" --config /tmp/ignored --drun-launch=true >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "tofi-drun wrapper should fall back to fuzzel (status=$status)"
  fi

  output=$(<"$log_file")
  [[ $output == *"--namespace=tofi"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi-drun wrapper should preserve the tofi namespace"
  }
  [[ $output != *"--dmenu"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi-drun wrapper should launch fuzzel app mode, not dmenu mode"
  }

  rm -rf "$temp_dir"
}

assert_tofi_wrappers_fall_back_to_system_tofi_when_fuzzel_missing() {
  local temp_dir home_dir bin_dir log_file output status

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  log_file="$temp_dir/tofi.log"
  status=0

  mkdir -p "$home_dir" "$bin_dir"

  cat > "$bin_dir/tofi" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'cmd=tofi\n' >> "$TOFI_LOG_FILE"
printf 'arg=%s\n' "$@" >> "$TOFI_LOG_FILE"
EOF

  cat > "$bin_dir/tofi-drun" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'cmd=tofi-drun\n' >> "$TOFI_LOG_FILE"
printf 'arg=%s\n' "$@" >> "$TOFI_LOG_FILE"
EOF

  chmod +x "$bin_dir/tofi" "$bin_dir/tofi-drun"

  printf 'one\ntwo\n' | HOME="$home_dir" \
    PATH="$bin_dir" \
    TOFI_LOG_FILE="$log_file" \
    /bin/bash "$ROOT_DIR/bin/tofi" --config /tmp/system --prompt-text "Pick: " >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "tofi wrapper should fall back to system tofi when fuzzel is missing (status=$status)"
  fi

  output=$(<"$log_file")
  [[ $output == *"cmd=tofi"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi wrapper should invoke system tofi when fuzzel is missing"
  }
  [[ $output == *"arg=--config"* && $output == *"arg=/tmp/system"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi wrapper should preserve system tofi config arguments"
  }
  [[ $output == *"arg=--prompt-text"* && $output == *"arg=Pick: "* ]] || {
    rm -rf "$temp_dir"
    fail "tofi wrapper should preserve system tofi prompt arguments"
  }

  : > "$log_file"
  HOME="$home_dir" \
    PATH="$bin_dir" \
    TOFI_LOG_FILE="$log_file" \
    /bin/bash "$ROOT_DIR/bin/tofi-drun" --config /tmp/system --drun-launch=true >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "tofi-drun wrapper should fall back to system tofi-drun when fuzzel is missing (status=$status)"
  fi

  output=$(<"$log_file")
  [[ $output == *"cmd=tofi-drun"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi-drun wrapper should invoke system tofi-drun when fuzzel is missing"
  }
  [[ $output == *"arg=--config"* && $output == *"arg=/tmp/system"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi-drun wrapper should preserve system tofi-drun config arguments"
  }
  [[ $output == *"arg=--drun-launch=true"* ]] || {
    rm -rf "$temp_dir"
    fail "tofi-drun wrapper should preserve system tofi-drun launch arguments"
  }

  rm -rf "$temp_dir"
}

assert_terminal_wrapper_prefers_configured_terminal_and_maps_flags
assert_tofi_wrappers_fall_back_to_fuzzel
assert_tofi_wrappers_fall_back_to_system_tofi_when_fuzzel_missing

echo "PASS: terminal and launcher wrapper tests"
