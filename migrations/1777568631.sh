echo "Install Bibata cursor theme and set desktop cursor preference"

cursor_theme="Bibata-Modern-Classic"

bibata_cursor_present() {
  [[ -d /usr/share/icons/$cursor_theme || -d $HOME/.local/share/icons/$cursor_theme ]]
}

if ! bibata_cursor_present; then
  if ryoku-cmd-missing yay && ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
    echo "  bootstrapping yay for Bibata cursor install"
    RYOKU_ONLINE_INSTALL=1 bash "$RYOKU_PATH/install/preflight/yay-bootstrap.sh" || true
  fi

  if ryoku-pkg-aur-accessible; then
    ryoku-pkg-aur-add bibata-cursor-theme-bin || true
  else
    echo "  AUR unavailable; skipping Bibata cursor install for now"
  fi
fi

if bibata_cursor_present && ryoku-cmd-present gsettings; then
  gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" || true
  gsettings set org.gnome.desktop.interface cursor-size 24 || true
fi
