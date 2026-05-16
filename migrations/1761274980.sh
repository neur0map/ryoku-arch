echo "Migrate to proper packages for localsend and asdcontrol"

installed_localsend="$(pacman -Qq localsend 2>/dev/null || true)"
if [[ $installed_localsend == "localsend" ]]; then
  ryoku-pkg-drop localsend
  ryoku-pkg-add localsend-bin
fi

if ryoku-pkg-present asdcontrol-git; then
  ryoku-pkg-drop asdcontrol-git
  ryoku-pkg-add asdcontrol
fi
