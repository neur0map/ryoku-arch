# Set links for Nautilus action icons. yaru-icon-theme is currently disabled
# upstream (orphaned AUR), so only relink when the Yaru theme is actually
# present - otherwise `ln` fails and halts the whole install via the error trap.
if [[ -d /usr/share/icons/Yaru/scalable/actions ]]; then
  sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
  sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg
fi

# Setup user theme folder
mkdir -p ~/.config/ryoku/themes

rm -rf ~/.config/chromium/SingletonLock # otherwise archiso will own the chromium singleton

# Set specific app links only when the user has opted into a Ryoku theme.
if [[ -f $HOME/.config/ryoku/current/theme/btop.theme ]]; then
  mkdir -p ~/.config/btop/themes
  ln -snf ~/.config/ryoku/current/theme/btop.theme ~/.config/btop/themes/current.theme
fi

# Default Chromium to follow system appearance ("device") instead of dark.
# Chromium is not a default Ryoku package, so only write its prefs when its
# install dir exists (a bare `tee` here would fail and halt the install).
if [[ -d /usr/lib/chromium ]]; then
  echo '{"browser":{"theme":{"color_scheme":0}}}' | sudo tee /usr/lib/chromium/initial_preferences >/dev/null
fi
