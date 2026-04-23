echo "Update fastfetch config with new Omarchy logo"

ryoku-refresh-config fastfetch/config.jsonc

mkdir -p ~/.config/ryoku/branding
cp $OMARCHY_PATH/icon.txt ~/.config/ryoku/branding/about.txt
