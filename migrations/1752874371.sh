echo "Add Catppuccin Latte light theme"

if [[ ! -L $HOME/.config/ryoku/themes/catppuccin-latte ]]; then
  ln -snf ~/.local/share/omarchy/themes/catppuccin-latte ~/.config/ryoku/themes/
fi
