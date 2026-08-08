#!/usr/bin/env bash
# nacre-popup-probe: loads shell components against the CONSOLIDATED quickshell
# tree (ryoku/shell/quickshell/shell), not the retired `pill` config.
#
# The scaffold is a faithful mirror of shell/ used as the config folder, so the
# built-in bar popout's own deep relative imports (../../../services,
# ../../../components) resolve inside the config folder the way quickshell
# requires. Ryoku.* QML modules come from QML2_IMPORT_PATH; Ryoku.Blobs is the
# installed C++ plugin under ~/.local/lib/qt6/qml.
#
# TWO HALVES:
#   1. BUILT-IN (nacre-popup-probe.qml) - the consolidated bar Popout
#      (shell/modules/bar/popouts/Popout.qml) and the Media singleton
#      (shell/services/Media.qml). This MUST pass; a failure exits non-zero.
#   2. EXTERNAL (nacre-popup-probe.barstyles.qml) - the nacre/obi barstyle
#      PRODUCTS from ryoku-extras, copied into the built-in barstyle dir.
#
# Both halves MUST pass. The external products import the shell.services +
# shell.barkit SDK (docs/barstyles.md): shell.services shares the shell's live
# singletons (so a product's Notifs is the one notification server, never a
# second), and shell.barkit re-exports the non-singleton primitives (icon and
# brand types, MusicBars, TrayMenu, NotificationCard, the Popout bases, the
# audio/notification menus). When ryoku-extras is absent half 2 is skipped; when
# present it must load or the probe exits non-zero. Commit nothing.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
src="$repo/ryoku/shell/quickshell/shell"
extras="${RYOKU_EXTRAS_ROOT:-$repo/../ryoku-extras-catalogue}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- faithful shell/ mirror as the config folder ------------------------------
# Mirror every top-level child of shell/ (symlinks to the real tree) but keep
# modules/bar/barstyles writable so external products can be dropped in beside
# the built-in `sumi`.
mkdir -p "$work/Ryoku" "$work/shell/modules/bar/barstyles"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
ln -s "$repo/ryoku/shell/framebars" "$work/Ryoku/FrameBars"
for child in "$src"/*; do
    name="$(basename "$child")"
    [[ "$name" == modules ]] && continue
    ln -s "$child" "$work/shell/$name"
done
for child in "$src/modules"/*; do
    name="$(basename "$child")"
    [[ "$name" == bar ]] && continue
    ln -s "$child" "$work/shell/modules/$name"
done
for child in "$src/modules/bar"/*; do
    name="$(basename "$child")"
    [[ "$name" == barstyles ]] && continue
    ln -s "$child" "$work/shell/modules/bar/$name"
done
ln -s "$src/modules/bar/barstyles/sumi" "$work/shell/modules/bar/barstyles/sumi"

cp "$here/nacre-popup-probe.qml" "$work/shell/probe.qml"
cp "$here/nacre-popup-probe.barstyles.qml" "$work/shell/probe-barstyles.qml"

impath="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}"

# --- half 1: BUILT-IN (must pass) ---------------------------------------------
QML2_IMPORT_PATH="$impath" timeout 20 qs -p "$work/shell/probe.qml" >"$work/builtin.log" 2>&1 || true
if ! grep -q NACRE-POPUP-PROBE-PASS "$work/builtin.log"; then
    echo "nacre-popup-probe: BUILT-IN half FAILED (Popout / Media did not load)" >&2
    sed -n '1,100p' "$work/builtin.log"
    exit 1
fi
if grep -Eq ' ERROR|TypeError|ReferenceError|is not a type|Type .* unavailable' "$work/builtin.log"; then
    echo "nacre-popup-probe: BUILT-IN half errored" >&2
    sed -n '1,100p' "$work/builtin.log"
    exit 1
fi

# --- half 2: EXTERNAL barstyle products (must load when present) --------------
if [[ -f "$extras/barstyles/nacre/manifest.json" && -f "$extras/barstyles/obi/manifest.json" ]]; then
    cp -a "$extras/barstyles/nacre" "$extras/barstyles/obi" "$work/shell/modules/bar/barstyles/"
    QML2_IMPORT_PATH="$impath" timeout 20 qs -p "$work/shell/probe-barstyles.qml" >"$work/barstyles.log" 2>&1 || true
    if ! grep -q NACRE-BARSTYLE-PROBE-PASS "$work/barstyles.log"; then
        echo "nacre-popup-probe: FAIL external nacre/obi barstyle products did not load" >&2
        sed -n '1,120p' "$work/barstyles.log" >&2
        exit 1
    fi
    if grep -Eq ' ERROR|TypeError|ReferenceError|is not a type|Type .* unavailable' "$work/barstyles.log"; then
        echo "nacre-popup-probe: FAIL external barstyle products loaded with errors" >&2
        sed -n '1,120p' "$work/barstyles.log" >&2
        exit 1
    fi
    echo "nacre-popup-probe: external nacre/obi barstyle products load"
else
    echo "SKIP: external barstyle products not present at $extras (set RYOKU_EXTRAS_ROOT)"
fi

echo "nacre-popup-probe: built-in Popout and Media load"
