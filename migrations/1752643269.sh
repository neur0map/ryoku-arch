echo "Add new matte black theme"

if [[ ! -L $HOME/.config/ryoku/themes/matte-black ]]; then
  ln -snf ~/.local/share/omarchy/themes/matte-black ~/.config/ryoku/themes/
fi
