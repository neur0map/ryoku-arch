echo "Install Greek Noir as the default Ryoku color theme"

MARKER="$HOME/.local/state/ryoku/independence-cutover.greek-noir.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

THEME_NAME="greek-noir"
THEME_REPO="https://github.com/HANCORE-linux/omarchy-greek-noir-theme.git"

# Already on a theme other than one from the original omarchy defaults?
# Respect the user's pick; still make sure the tofi.conf gets rendered.
CURRENT=""
if [[ -f $HOME/.config/ryoku/current/theme.name ]]; then
  CURRENT=$(cat "$HOME/.config/ryoku/current/theme.name")
fi

if [[ -d $HOME/.config/ryoku/themes/$THEME_NAME ]]; then
  echo "  $THEME_NAME already installed"
else
  ryoku-theme-install "$THEME_REPO" || {
    echo "  could not install $THEME_NAME (network?); leaving current theme active."
    mkdir -p "$HOME/.local/state/ryoku"
    touch "$MARKER"
    exit 0
  }
fi

# Don't stomp on a user who already customized their theme selection.
# Greek Noir only becomes the active theme if the previous active theme
# was one of the omarchy-shipped defaults (or unset).
case "$CURRENT" in
  ""|tokyo-night|catppuccin|catppuccin-latte|kanagawa|gruvbox|nord|everforest)
    ryoku-theme-set "$THEME_NAME"
    echo "  set active theme: $THEME_NAME"
    ;;
  "$THEME_NAME")
    ryoku-theme-set "$THEME_NAME"  # re-render templates (incl. tofi.conf)
    ;;
  *)
    echo "  current theme is '$CURRENT'; keeping it (Greek Noir is installed and selectable)"
    ;;
esac

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
