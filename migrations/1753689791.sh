echo "Add the new ristretto theme as an option"

if [[ ! -L ~/.config/ryoku/themes/ristretto ]]; then
  ln -nfs ~/.local/share/omarchy/themes/ristretto ~/.config/ryoku/themes/
fi
