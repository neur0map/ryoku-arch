echo "Migrate to proper packages for localsend and asdcontrol"

if ryoku-pkg-present localsend-bin; then
  ryoku-pkg-drop localsend-bin
  ryoku-pkg-add localsend
fi

if ryoku-pkg-present asdcontrol-git; then
  ryoku-pkg-drop asdcontrol-git
  ryoku-pkg-add asdcontrol
fi
