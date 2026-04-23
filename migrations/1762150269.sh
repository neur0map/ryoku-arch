[[ -f $HOME/.local/state/ryoku/independence-cutover.launcher.done ]] && exit 0

echo "Install omarchy-walker meta package"
ryoku-pkg-add omarchy-walker
