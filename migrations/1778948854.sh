echo "Repair missing icon theme and LocalSend package defaults"

if [[ -x $RYOKU_PATH/bin/ryoku-refresh-icon-theme ]]; then
  "$RYOKU_PATH/bin/ryoku-refresh-icon-theme" || true
fi

installed_localsend="$(pacman -Qq localsend 2>/dev/null || true)"
if [[ $installed_localsend == "localsend" ]]; then
  echo "  switching LocalSend source package back to localsend-bin"
  ryoku-pkg-drop localsend || true
  ryoku-pkg-add localsend-bin || true
fi
