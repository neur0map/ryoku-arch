echo "Ensure LocalSend is installed from the binary package"

installed_localsend="$(pacman -Qq localsend 2>/dev/null || true)"
if [[ $installed_localsend == "localsend" ]]; then
  ryoku-pkg-drop localsend
fi

ryoku-pkg-add localsend-bin
