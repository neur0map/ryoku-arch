echo "Make hackerman available as new theme"

if [[ ! -L ~/.config/ryoku/themes/hackerman ]]; then
  rm -rf ~/.config/ryoku/themes/hackerman
  ln -nfs ~/.local/share/omarchy/themes/hackerman ~/.config/ryoku/themes/
fi
