# Set links for Nautilus action icons
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg

# Setup user theme folder
mkdir -p ~/.config/ryoku/themes

# Install Greek Noir as the default Ryoku theme. The installer handles
# the omarchy- repo prefix and drops the theme into
# ~/.config/ryoku/themes/greek-noir. Falls back to Tokyo Night from the
# shipped library if the install cannot reach github (offline ISO etc.).
if ryoku-pkg-aur-accessible 2>/dev/null || ping -c1 -W2 github.com >/dev/null 2>&1; then
  ryoku-theme-install https://github.com/HANCORE-linux/omarchy-greek-noir-theme.git \
    && ryoku-theme-set "greek-noir" \
    || ryoku-theme-set "Tokyo Night"
else
  ryoku-theme-set "Tokyo Night"
fi
rm -rf ~/.config/chromium/SingletonLock # otherwise archiso will own the chromium singleton

# Set specific app links for current theme
mkdir -p ~/.config/btop/themes
ln -snf ~/.config/ryoku/current/theme/btop.theme ~/.config/btop/themes/current.theme

# Add managed policy directories for Chromium and Brave for theme changes
sudo mkdir -p /etc/chromium/policies/managed
sudo chmod a+rw /etc/chromium/policies/managed

sudo mkdir -p /etc/brave/policies/managed
sudo chmod a+rw /etc/brave/policies/managed

# Default Chromium to follow system appearance ("device") instead of dark
echo '{"browser":{"theme":{"color_scheme":0}}}' | sudo tee /usr/lib/chromium/initial_preferences >/dev/null
