echo "Soften HyprMod blur filtering while preserving transparency"

hyprmod_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland-gui.conf"

if [[ -f $hyprmod_conf ]]; then
  sed -i \
    -e 's/^decoration:blur:brightness = 0\.75$/decoration:blur:brightness = 1.0/' \
    -e 's/^decoration:blur:contrast = 1\.7$/decoration:blur:contrast = 1.0/' \
    -e 's/^decoration:blur:vibrancy = 0\.2$/decoration:blur:vibrancy = 0.0/' \
    -e 's/^decoration:blur:vibrancy_darkness = 0\.7$/decoration:blur:vibrancy_darkness = 0.0/' \
    "$hyprmod_conf"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
