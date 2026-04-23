# Copy over Ryoku configs
mkdir -p ~/.config
cp -R ~/.local/share/ryoku/config/* ~/.config/

# Use default bashrc from Ryoku
cp ~/.local/share/ryoku/default/bashrc ~/.bashrc
