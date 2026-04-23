echo "Replace wofi with walker as the default launcher"

if ryoku-cmd-missing walker; then
  ryoku-pkg-add walker-bin libqalculate

  ryoku-pkg-drop wofi
  rm -rf ~/.config/wofi

  mkdir -p ~/.config/walker
  cp -r ~/.local/share/omarchy/config/walker/* ~/.config/walker/
fi
