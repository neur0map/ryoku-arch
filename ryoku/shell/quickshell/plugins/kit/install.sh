#!/usr/bin/env bash
# put the Ryoku.PluginKit QML module on the import path so plugin content
# (loaded from outside the shell tree) can `import Ryoku.PluginKit`. mirrors
# how plugin/build.sh installs Ryoku.Blobs. pure QML -> a copy, not a build.
#
#   install.sh [<qml-import-root>]   (default: ~/.local/lib/qt6/qml)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$HOME/.local/lib/qt6/qml}"
dest="$root/Ryoku/PluginKit"

mkdir -p "$dest"
# wipe first so a removed component doesn't linger on the import path.
rm -rf "$dest"
mkdir -p "$dest"
cp -r "$here/." "$dest/"
rm -f "$dest/install.sh"
echo "installed Ryoku.PluginKit -> $dest"
