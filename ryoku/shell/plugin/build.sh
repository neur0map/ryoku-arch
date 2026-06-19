#!/usr/bin/env bash
# Build the Ryoku.Blobs QML plugin and install the module onto a QML import path.
#
#   build.sh <qml-import-dir>
#
# Produces <qml-import-dir>/Ryoku/Blobs/{libryoku-blobs.so, qmldir, *.qsb, ...}.
# Quickshell loads it from there once that dir is on QML2_IMPORT_PATH (ryoku-shell
# sets that for the components it supervises). The target has no build toolchain,
# so this runs on the dev box (deploy.sh) and the ISO build host (iso/build.sh),
# never on the installed machine. Build deps: cmake, ninja, qt6-shadertools, a
# C++20 compiler, and the Qt6 development files.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dest="${1:?usage: build.sh <qml-import-dir>}"
build="${RYOKU_BLOBS_BUILD:-$here/build}"

for tool in cmake ninja; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'build.sh: error: %s is required (pacman -S cmake ninja qt6-shadertools)\n' "$tool" >&2
    exit 1
  }
done

cmake -S "$here" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$build"

# The module is self-contained under <build>/qml/Ryoku/Blobs; replace any prior
# copy so a renamed/removed file never lingers on the import path.
mkdir -p "$dest/Ryoku"
rm -rf "$dest/Ryoku/Blobs"
cp -a "$build/qml/Ryoku/Blobs" "$dest/Ryoku/Blobs"

# Drop the generated .qrc dir-map; it is a build byproduct, not a runtime file.
rm -f "$dest/Ryoku/Blobs"/*.qrc
