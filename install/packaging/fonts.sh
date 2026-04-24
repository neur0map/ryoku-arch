# Ryoku logo in a font for Waybar use
mkdir -p ~/.local/share/fonts
cp "$RYOKU_PATH/config/ryoku.ttf" ~/.local/share/fonts/
fc-cache
