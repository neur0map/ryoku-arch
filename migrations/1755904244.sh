echo "Update fastfetch config with new Ryoku logo"

ryoku-refresh-config fastfetch/config.jsonc

mkdir -p ~/.config/ryoku/branding
cp $RYOKU_PATH/icon.txt ~/.config/ryoku/branding/about.txt
