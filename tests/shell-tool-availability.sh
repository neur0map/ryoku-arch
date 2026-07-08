#!/usr/bin/env bash
# Prevent the "feature wired but its tool is not shipped" class: every external
# program a Ryoku desktop feature depends on must be shipped by a package set
# (base/dev/aur). This is a curated feature -> package map; add a row when a new
# feature starts shelling out to a new tool.
set -euo pipefail

ROOT=${RYOKU_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
pkgs="$ROOT/system/packages"

ships() {
  grep -qxF "$1" "$pkgs/base.packages" "$pkgs/dev.packages" "$pkgs/aur.packages" 2>/dev/null
}

# feature -> package that provides it
declare -A need=(
  [wallpaper-daemon]=awww-git
  [palette]=wallust
  [clipboard-history]=cliphist
  [color-picker]=hyprpicker
  [music-visualizer]=cava
  [led-color]=openrgb
  [screenshot]=grim
  [region-select]=slurp
  [ocr]=tesseract
  [qr-scan]=zbar
  [screen-record]=gpu-screen-recorder
  [screen-record-fallback]=wf-recorder
  [night-light]=hyprsunset
  [voice-type]=wtype
  [voice-stt]=voxtype-bin
  [media-control]=playerctl
  [brightness]=brightnessctl
  [idle]=hypridle
  [battery]=upower
  [shell]=quickshell
  [terminal]=kitty
  [browser]=chromium
  [files]=nautilus
  [editor]=neovim
  [file-cli]=yazi
  [video]=mpv
  [calc]=libqalculate
  [music-mpris]=mpv-mpris
  [music-recognition]=songrec
  [display-brightness]=ddcutil
  [vibrance]=nvibrant-bin
)

missing=()
for feat in "${!need[@]}"; do
  pkg=${need[$feat]}
  ships "$pkg" || missing+=("$feat -> $pkg")
done

if (( ${#missing[@]} )); then
  echo "::error::shell features whose package is not in any package set:" >&2
  printf '  %s\n' "${missing[@]}" | sort >&2
  exit 1
fi

echo "shell-tool-availability: all ${#need[@]} gated feature packages are shipped"
