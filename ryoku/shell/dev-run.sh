#!/usr/bin/env bash
# run the Ryoku shell straight from this repo on the live Hyprland session, no
# install. daemon launches each component with `qs -p <repo>/quickshell/...`
# and quickshell hot-reloads QML edits, so changes show live. your ~/.config
# stays untouched. dev-stop.sh to stop.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bin="$here/ipc/ryoku-shell"

(cd "$here/ipc" && go build -o ryoku-shell .)

# the frame component imports Ryoku.Blobs from the QML path the daemon sets,
# so build + install it once = dev loop renders the frame like a real deploy.
"$here/plugin/build.sh" "$HOME/.local/lib/qt6/qml"

export RYOKU_SHELL_DIR="$here"
echo "ryoku-shell dev  (RYOKU_SHELL_DIR=$here)"
echo "  edit anything under $here/quickshell and it reloads live"
echo "  test actions:  $bin <launcher|clipboard|link|lock|wallpaper|wallpaper-picker|status>"
echo "  add keybinds:  $here/dev-binds.sh on    (restore yours with: hyprctl reload)"
echo "  stop:          $here/dev-stop.sh"
exec "$bin" daemon
