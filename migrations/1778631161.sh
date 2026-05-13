echo "Move Helium AppImage outside Ryoku git checkout"

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
legacy_app_dir="$data_home/ryoku/apps/helium"
legacy_appimage_path="$legacy_app_dir/helium.AppImage"
app_dir="$data_home/ryoku-apps/helium"
appimage_path="$app_dir/helium.AppImage"
bin_path="$HOME/.local/bin/helium"

if [[ -f $legacy_appimage_path ]]; then
  mkdir -p "$app_dir" "$HOME/.local/bin"

  if [[ ! -f $appimage_path ]]; then
    mv "$legacy_appimage_path" "$appimage_path"
  else
    rm -f "$legacy_appimage_path"
  fi

  chmod 0755 "$appimage_path"
  ln -sfn "$appimage_path" "$bin_path"
  rmdir "$legacy_app_dir" "$data_home/ryoku/apps" 2>/dev/null || true
fi
