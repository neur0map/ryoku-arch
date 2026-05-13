# Set links for Nautilus action icons
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg

# Setup user theme folder
mkdir -p ~/.config/ryoku/themes

rm -rf ~/.config/chromium/SingletonLock # otherwise archiso will own the chromium singleton

# Set specific app links only when the user has opted into a Ryoku theme.
if [[ -f $HOME/.config/ryoku/current/theme/btop.theme ]]; then
  mkdir -p ~/.config/btop/themes
  ln -snf ~/.config/ryoku/current/theme/btop.theme ~/.config/btop/themes/current.theme
fi

# Default Chromium to follow system appearance ("device") instead of dark
echo '{"browser":{"theme":{"color_scheme":0}}}' | sudo tee /usr/lib/chromium/initial_preferences >/dev/null
