#!/usr/bin/env bash
# Does the dossier's barcode still scan?
#
# The edition strip carries a real Code 39 rather than a bar-shaped ornament,
# because someone will point a phone at it. That claim needs a machine to check
# it: a wrong glyph table and a clipped render both still look like a barcode.
set -euo pipefail

command -v zbarimg >/dev/null || { echo "zbar not installed"; exit 77; }
command -v grim    >/dev/null || { echo "no compositor to render in"; exit 77; }

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
want="RYOKU-KUROGANE-20260717"

cat > "$work/shell.qml" <<QML
import QtQuick
import Quickshell
import Ryoku.Ui
import Ryoku.Ui.Singletons
ShellRoot {
    FloatingWindow {
        title: "barcode-test"
        minimumSize: Qt.size(1400, 140)
        color: Tokens.paper
        onClosed: Qt.quit()
        Barcode { anchors.centerIn: parent; text: "$want" }
    }
}
QML

QML_IMPORT_PATH="${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
  setsid qs -p "$work" >"$work/log" 2>&1 &
sleep 5

# A tiled window ignores minimumSize and clips the code, which is the exact
# silent failure this guards: it still looks like a barcode.
addr=$(hyprctl clients -j | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    if c['title'] == 'barcode-test': print(c['address'])" || true)
hyprctl dispatch "hl.dsp.focus({ window = '$addr' })" >/dev/null 2>&1 || true
sleep 1
hyprctl dispatch 'hl.dsp.window.float()' >/dev/null 2>&1 || true
sleep 1
hyprctl dispatch 'hl.dsp.window.resize({ x = 1400, y = 150, exact = true })' >/dev/null 2>&1 || true
sleep 1
hyprctl dispatch 'hl.dsp.window.center()' >/dev/null 2>&1 || true
sleep 1

geom=$(hyprctl clients -j | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    if c['title'] == 'barcode-test':
        x, y = c['at']; w, h = c['size']; print(f'{x},{y} {w}x{h}')" || true)
[ -n "$geom" ] || { echo "window never appeared"; sed -n '1,10p' "$work/log"; exit 1; }
grim -g "$geom" "$work/shot.png"
# (the window is closed by pid below; pkill -f would match this script itself)
hyprctl clients -j | python3 -c "
import sys, json, os, signal
for c in json.load(sys.stdin):
    if c['title'] == 'barcode-test': os.kill(c['pid'], signal.SIGTERM)" 2>/dev/null || true

python3 - "$work/shot.png" "$work/scan.png" <<'PY'
import sys
from PIL import Image, ImageOps
im = Image.open(sys.argv[1]).convert("L")
im = im.crop((0, int(im.height * 0.32), im.width, int(im.height * 0.67)))
im = ImageOps.invert(im)                       # ink bars are light; scanners want dark
q = Image.new("L", (im.width + 200, im.height + 40), 255)   # Code 39 needs a quiet zone
q.paste(im, (100, 20))
q.resize((q.width * 2, q.height * 2), Image.LANCZOS).save(sys.argv[2])
PY

got=$(zbarimg --quiet --raw "$work/scan.png" 2>/dev/null | tr -d '\r\n')
[ "$got" = "$want" ] || { echo "FAIL: scanned '$got', wanted '$want'"; exit 1; }
echo "barcode: scans as $got"
