echo "Add the new Flexoki Light theme"

if [[ ! -L ~/.config/ryoku/themes/flexoki-light ]]; then
  ln -nfs ~/.local/share/omarchy/themes/flexoki-light ~/.config/ryoku/themes/
fi
