echo "Make light themes possible"

if [[ -f ~/.local/share/applications/blueberry.desktop ]]; then
  rm -f ~/.local/share/applications/blueberry.desktop
  rm -f ~/.local/share/applications/org.pulseaudio.pavucontrol.desktop
  update-desktop-database ~/.local/share/applications/

  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"

  ryoku-refresh-waybar
fi

config_theme_dir="$HOME/.config/ryoku/themes"
ryoku_theme_dir="${RYOKU_PATH:-$HOME/.local/share/ryoku}/themes/rose-pine"
legacy_theme_dir="$HOME/.local/share/omarchy/themes/rose-pine"
user_theme_link="$config_theme_dir/rose-pine"

mkdir -p "$config_theme_dir"

if [[ -e $user_theme_link && ! -L $user_theme_link ]]; then
  echo "  preserving existing rose-pine theme"
elif [[ ! -L $user_theme_link ]]; then
  if [[ -d $ryoku_theme_dir ]]; then
    ln -snf "$ryoku_theme_dir" "$user_theme_link"
  elif [[ -d $legacy_theme_dir ]]; then
    ln -snf "$legacy_theme_dir" "$user_theme_link"
  else
    echo "  rose-pine theme not found; skipping compatibility symlink"
  fi
fi
