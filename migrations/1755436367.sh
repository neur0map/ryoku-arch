echo "Add minimal starship prompt to terminal"

if ryoku-cmd-missing starship; then
  ryoku-pkg-add starship
  cp $RYOKU_PATH/config/starship.toml ~/.config/starship.toml
fi
