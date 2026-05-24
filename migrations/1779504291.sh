echo "Switch lockscreen to upstream qylock launcher and smooth Hyprland opening animations"

QYLOCK_DIR="$HOME/.local/share/qylock"
QYLOCK_LOCK_DIR="$HOME/.local/share/quickshell-lockscreen"
QYLOCK_LOCK_SCRIPT="$QYLOCK_LOCK_DIR/lock.sh"
QYLOCK_THEME_FILE="$HOME/.config/qylock/theme"
DEFAULT_QYLOCK_THEME="clockwork/orbital"

read_active_sddm_theme() {
  local current="" file value
  local sddm_conf_dir="/etc/sddm.conf.d"
  local sddm_conf_file="/etc/sddm.conf"

  shopt -s nullglob
  for file in "$sddm_conf_file" "$sddm_conf_dir"/*.conf; do
    [[ -f $file ]] || continue
    value=$(awk -F= '
      /^[[:space:]]*Current[[:space:]]*=/ {
        v = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        print v
      }
    ' "$file" | tail -n1)
    [[ -n $value ]] && current="$value"
  done

  printf '%s\n' "$current"
}

normalize_qylock_theme() {
  local theme="$1"

  case "$theme" in
    clockwork)
      printf '%s\n' "$DEFAULT_QYLOCK_THEME"
      ;;
    orbital|tape)
      printf 'clockwork/%s\n' "$theme"
      ;;
    *)
      printf '%s\n' "$theme"
      ;;
  esac
}

select_qylock_theme() {
  local theme

  theme=$(read_active_sddm_theme)
  theme=$(normalize_qylock_theme "$theme")
  if [[ -n $theme && -f $QYLOCK_DIR/themes/$theme/Main.qml ]]; then
    printf '%s\n' "$theme"
    return
  fi

  if [[ -s $QYLOCK_THEME_FILE ]]; then
    theme=$(head -n1 "$QYLOCK_THEME_FILE")
    theme=$(normalize_qylock_theme "$theme")
    if [[ -n $theme && -f $QYLOCK_DIR/themes/$theme/Main.qml ]]; then
      printf '%s\n' "$theme"
      return
    fi
  fi

  printf '%s\n' "$DEFAULT_QYLOCK_THEME"
}

if [[ -d $QYLOCK_DIR/.git ]] && command -v git >/dev/null 2>&1; then
  git -C "$QYLOCK_DIR" pull --ff-only >/dev/null \
    || echo "  qylock update skipped; rerun 'git -C ~/.local/share/qylock pull --ff-only' after resolving local state" >&2
fi

if [[ -d $QYLOCK_DIR/quickshell-lockscreen ]]; then
  rm -rf "$QYLOCK_LOCK_DIR"
  cp -R "$QYLOCK_DIR/quickshell-lockscreen" "$QYLOCK_LOCK_DIR"
  ln -sfn "$QYLOCK_DIR/themes" "$QYLOCK_LOCK_DIR/themes_link"
  chmod +x "$QYLOCK_LOCK_SCRIPT"

  mkdir -p "$(dirname "$QYLOCK_THEME_FILE")"
  printf '%s\n' "$(select_qylock_theme)" >"$QYLOCK_THEME_FILE"
else
  echo "  qylock checkout not found; run 'ryoku-install-qylock --default' to install it" >&2
fi

set_hyprland_lock_bind() {
  local conf="$1"
  local lock_line="\$lockscreen = sh -lc 'exec env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST \"\$HOME/.local/share/quickshell-lockscreen/lock.sh\"'"

  [[ -f $conf ]] || return 0

  if grep -q '^[$]lockscreen[[:space:]]*=' "$conf"; then
    sed -i "s|^\$lockscreen[[:space:]]*=.*|$lock_line|" "$conf"
  elif grep -q '^[$]powerMenu[[:space:]]*=' "$conf"; then
    sed -i "/^\$powerMenu[[:space:]]*=/a $lock_line" "$conf"
  else
    printf '%s\n' "$lock_line" >>"$conf"
  fi

  if grep -q '^bind = SUPER ALT, L, exec,' "$conf"; then
    sed -i "s|^bind = SUPER ALT, L, exec, .*|bind = SUPER ALT, L, exec, \$lockscreen|" "$conf"
  else
    printf '%s\n' "bind = SUPER ALT, L, exec, \$lockscreen" >>"$conf"
  fi
}

set_smooth_opening_animations() {
  local conf="$1"
  local smooth_bezier="  bezier = smoothOpen,0.12,0,0.20,1"
  local windows_in="  animation = windowsIn, 1, 5, smoothOpen, popin 85%"
  local fade_in="  animation = fadeIn, 1, 5, smoothOpen"

  [[ -f $conf ]] || return 0

  if grep -q '^  bezier = smoothOpen,' "$conf"; then
    sed -i "s|^  bezier = smoothOpen,.*|$smooth_bezier|" "$conf"
  elif grep -q '^  bezier = easeOut,' "$conf"; then
    sed -i "/^  bezier = easeOut,/a\\$smooth_bezier" "$conf"
  elif grep -q '^animations {' "$conf"; then
    sed -i "/^animations {/a\\$smooth_bezier" "$conf"
  fi

  if grep -q '^  animation = windowsIn,' "$conf"; then
    sed -i "s|^  animation = windowsIn,.*|$windows_in|" "$conf"
  elif grep -q '^  animation = windows,' "$conf"; then
    sed -i "/^  animation = windows,/a\\$windows_in" "$conf"
  elif grep -q '^animations {' "$conf"; then
    sed -i "/^animations {/a\\$windows_in" "$conf"
  fi

  if grep -q '^  animation = fadeIn,' "$conf"; then
    sed -i "s|^  animation = fadeIn,.*|$fade_in|" "$conf"
  elif grep -q '^  animation = fade,' "$conf"; then
    sed -i "/^  animation = fade,/a\\$fade_in" "$conf"
  elif grep -q '^animations {' "$conf"; then
    sed -i "/^animations {/a\\$fade_in" "$conf"
  fi
}

set_hypridle_lock_cmd() {
  local conf="$1"
  local lock_cmd="    lock_cmd         = /bin/sh -c 'exec env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST \"\$HOME/.local/share/quickshell-lockscreen/lock.sh\"'"

  [[ -f $conf ]] || return 0
  sed -i "s|^[[:space:]]*lock_cmd[[:space:]]*=.*|$lock_cmd|" "$conf"
  sed -i \
    -e "s|# .*Settings-selected SDDM Current= theme.|# lock command calls qylock's upstream Quickshell lockscreen directly.|" \
    -e "/# If that theme belongs to qylock, qylock's external Quickshell lockscreen is/d" \
    -e "/# used. Otherwise Ryoku falls back to hyprlock so suspend-driven locks still/d" \
    -e "/# present the default unlock UI./d" \
    -e "/# Lock surface choice , Settings-selected qylock themes for automated \\/$/d" \
    -e "/# suspend-driven locks; Ryoku's Lock.qml stays wired to Mod+Alt+L./d" \
    -e "s|# 10 minutes idle: lock the screen via DBus (which fires lock_cmd above)|# 10 minutes idle: ask logind to lock, which fires lock_cmd above.|" \
    "$conf"
}

set_hyprland_lock_bind "$HOME/.config/hypr/hyprland.conf"
set_smooth_opening_animations "$HOME/.config/hypr/hyprland.conf"
set_hypridle_lock_cmd "$HOME/.config/hypr/hypridle.conf"

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi

pkill -x hypridle >/dev/null 2>&1 || true
systemctl --user restart hypridle.service >/dev/null 2>&1 || true
