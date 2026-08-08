#!/usr/bin/env bash
# Put Ryoku.FrameBars on the QML import path so every config root -- the pill,
# launcher, widgets and plugin surfaces -- and the Hub's Bar Studio import one
# copy of the shared frame-bar schema and catalogs. Quickshell sandboxes a
# relative import to the running config root, so the shared JS cannot live in one
# root and be reached from the others; an installed module resolves everywhere.
# Pure QML + JS, so a copy, not a build. Mirrors plugins/kit/install.sh.
#
#   install.sh [<qml-import-root>]   (default: ~/.local/lib/qt6/qml)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$HOME/.local/lib/qt6/qml}"
dest="$root/Ryoku/FrameBars"

mkdir -p "$dest"
# wipe first so a removed component doesn't linger on the import path.
rm -rf "$dest"
mkdir -p "$dest"
cp -r "$here/." "$dest/"
rm -f "$dest/install.sh"
echo "installed Ryoku.FrameBars -> $dest"
