echo "Make ethereal available as new theme"

if [[ ! -L ~/.config/ryoku/themes/ethereal ]]; then
  rm -rf ~/.config/ryoku/themes/ethereal
  ln -nfs ~/.local/share/omarchy/themes/ethereal ~/.config/ryoku/themes/
fi
