#!/usr/bin/env bash
# Put Ryoku.Ui on the QML import path so every surface -- the shell's configs,
# the Hub, and the first-party apps -- imports one design system instead of
# carrying its own copy. Mirrors plugins/kit/install.sh. Pure QML, so a copy.
#
#   install.sh [<qml-import-root>]   (default: ~/.local/lib/qt6/qml)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$HOME/.local/lib/qt6/qml}"
dest="$root/Ryoku/Ui"

rm -rf "$dest"
mkdir -p "$dest"
cp -r "$here/." "$dest/"
rm -f "$dest/install.sh"
echo "installed Ryoku.Ui -> $dest"
