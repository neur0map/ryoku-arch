echo "Switch lmstudio -> lmstudio-bin"

if pacman -Q lmstudio &>/dev/null; then
  ryoku-pkg-drop lmstudio
  ryoku-pkg-add lmstudio-bin
fi
