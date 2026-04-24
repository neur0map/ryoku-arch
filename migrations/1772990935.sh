echo "Add sample low battery notification hook"

mkdir -p ~/.config/ryoku/hooks

if [[ ! -f ~/.config/ryoku/hooks/battery-low.sample ]]; then
  cp "$RYOKU_PATH/config/omarchy/hooks/battery-low.sample" ~/.config/ryoku/hooks/battery-low.sample
fi
