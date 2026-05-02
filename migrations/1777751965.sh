echo "Clean old Hyprland shell config after Niri/iNiR migration"

if ! command -v inir >/dev/null 2>&1; then
  echo "iNiR is not installed; deferring old shell config cleanup"
  exit 75
fi

if ! command -v niri >/dev/null 2>&1; then
  echo "Niri is not installed; deferring old shell config cleanup"
  exit 75
fi

case "${XDG_CURRENT_DESKTOP:-}" in
  niri|Niri)
    ;;
  *)
    echo "Current desktop is not Niri; deferring old shell config cleanup"
    exit 75
    ;;
esac

for path in \
  "$HOME/.config/hypr" \
  "$HOME/.config/waybar" \
  "$HOME/.config/mako" \
  "$HOME/.config/swayosd" \
  "$HOME/.config/uwsm" \
  "$HOME/.config/elephant" \
  "$HOME/.config/quickshell/ryoku"
do
  if [[ -e $path ]]; then
    rm -rf "$path"
  fi
done

mkdir -p "$HOME/.config/ryoku/branding"

copy_screensaver_default() {
  local source="$1"
  local target="$2"

  [[ -f $source ]] || return 0
  [[ -e $target && $source -ef $target ]] && return 0

  mkdir -p "$(dirname "$target")"
  cp -f "$source" "$target"
}

copy_screensaver_default \
  "$RYOKU_PATH/default/alacritty/screensaver.toml" \
  "$HOME/.local/share/ryoku/default/alacritty/screensaver.toml"

copy_screensaver_default \
  "$RYOKU_PATH/default/ghostty/screensaver" \
  "$HOME/.local/share/ryoku/default/ghostty/screensaver"
