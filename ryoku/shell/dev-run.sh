#!/usr/bin/env bash
# Run the Ryoku shell straight from this repo on the running Hyprland session, with
# no install. The daemon launches each component with `qs -p <repo>/quickshell/...`,
# and quickshell hot-reloads QML edits, so changes show live. Your own ~/.config is
# never touched. Stop with dev-stop.sh.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bin="$here/ipc/ryoku-shell"

(cd "$here/ipc" && go build -o ryoku-shell .)

# The frame component imports the Ryoku.Blobs plugin from the QML import path the
# daemon sets; build + install it so the dev loop renders the frame like a deploy.
"$here/plugin/build.sh" "$HOME/.local/lib/qt6/qml"

export RYOKU_SHELL_DIR="$here"
echo "ryoku-shell dev  (RYOKU_SHELL_DIR=$here)"
echo "  edit anything under $here/quickshell and it reloads live"
echo "  test actions:  $bin <launcher|sidebar|clipboard|link|lock|wallpaper|wallpaper-picker|status>"
echo "  add keybinds:  $here/dev-binds.sh on    (restore yours with: hyprctl reload)"
echo "  stop:          $here/dev-stop.sh"
exec "$bin" daemon
