#!/bin/bash
# Guards GTK/Qt dynamic app recoloring (services.syncAppColors): the gtk.css +
# kdeglobals templates render from the palette with no leftover placeholders, the
# scheme/theme pipeline invokes the apply step, and ryoku-theme-set-qtgtk installs
# the colors as marker-delimited managed blocks that preserve user content, back up
# once, replace in place on re-run, and do nothing when the flag is off.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null || fail "jq is required for the app-color-sync test"

# ── 1. templates + config key + pipeline wiring ───────────────────────────────
gtktpl="$ROOT/default/themed/gtk.css.tpl"
kdetpl="$ROOT/default/themed/kdeglobals.tpl"
[[ -f $gtktpl ]] || fail "default/themed/gtk.css.tpl is missing"
[[ -f $kdetpl ]] || fail "default/themed/kdeglobals.tpl is missing"

grep -Eq 'CONFIG_GLOBAL_PROPERTY\(bool, syncAppColors' "$ROOT/shell/plugin/src/Ryoku/Config/serviceconfig.hpp" \
  || fail "serviceconfig.hpp must declare the syncAppColors key"

qtgtk="$ROOT/bin/ryoku-theme-set-qtgtk"
[[ -x $qtgtk ]] || fail "bin/ryoku-theme-set-qtgtk must be executable"
grep -q 'ryoku-theme-set-qtgtk' "$ROOT/bin/ryoku-scheme-set" \
  || fail "ryoku-scheme-set must invoke ryoku-theme-set-qtgtk"
grep -q 'ryoku-theme-set-qtgtk' "$ROOT/bin/ryoku-theme-set" \
  || fail "ryoku-theme-set must invoke ryoku-theme-set-qtgtk"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── 2. render test: no leftover {{ placeholders }} in our two outputs ──────────
C="$WORK/cfg"
mkdir -p "$C/current/next-theme"
{
  echo 'background = "#1e1e2e"'
  echo 'foreground = "#cdd6f4"'
  echo 'accent = "#89b4fa"'
  for i in $(seq 0 15); do printf 'color%d = "#%02x%02x%02x"\n' "$i" $((i*8)) $((i*4)) $((i*2)); done
} >"$C/current/next-theme/colors.toml"

RYOKU_PATH="$ROOT" RYOKU_CONFIG_PATH="$C" bash "$ROOT/bin/ryoku-theme-set-templates" \
  || fail "ryoku-theme-set-templates failed to render"
for out in gtk.css kdeglobals; do
  rendered="$C/current/next-theme/$out"
  [[ -f $rendered ]] || fail "$out was not rendered"
  ! grep -q '{{' "$rendered" || fail "$out has unrendered {{ placeholders }} (a template var is missing from colors.toml)"
done
# kdeglobals must carry decimal R,G,B (KDE format), not hex
grep -Eq 'BackgroundNormal=[0-9]+,[0-9]+,[0-9]+' "$C/current/next-theme/kdeglobals" \
  || fail "kdeglobals must render decimal R,G,B color triples"

# ── 3. apply test: managed blocks, backup, replace-in-place, off-state ─────────
mkdir -p "$C/current/theme"
cp "$C/current/next-theme/gtk.css" "$C/current/theme/gtk.css"
cp "$C/current/next-theme/kdeglobals" "$C/current/theme/kdeglobals"
X="$WORK/xdg"
mkdir -p "$X/gtk-4.0"
printf '/* my own tweak */\nwindow { padding: 4px; }\n' >"$X/gtk-4.0/gtk.css"

run_qt() { RYOKU_CONFIG_PATH="$C" XDG_CONFIG_HOME="$X" bash "$qtgtk" >/dev/null 2>&1; }

printf '{"services":{"syncAppColors":true}}\n' >"$C/shell.json"
run_qt || fail "qtgtk run failed (flag on)"
grep -q 'my own tweak' "$X/gtk-4.0/gtk.css" || fail "qtgtk must preserve pre-existing user gtk.css content"
grep -q 'accent_color' "$X/gtk-4.0/gtk.css" || fail "qtgtk must install the managed gtk color block"
(( $(grep -c 'ryoku managed colors' "$X/gtk-4.0/gtk.css") == 2 )) || fail "exactly one marker pair expected"
[[ -e $X/gtk-4.0/gtk.css.ryoku-bak ]] || fail "qtgtk must back up the pre-existing file once"
grep -q 'accent_color' "$X/gtk-3.0/gtk.css" || fail "qtgtk must write gtk-3.0 too"
grep -q 'BackgroundNormal' "$X/kdeglobals" || fail "qtgtk must install the managed kdeglobals block"
bak1="$(sha256sum "$X/gtk-4.0/gtk.css.ryoku-bak" | cut -d' ' -f1)"

# Re-run with a changed palette -> block replaced in place, still one pair, no re-backup.
sed -i 's/#89b4fa/#ff0000/' "$C/current/theme/gtk.css"
run_qt || fail "qtgtk second run failed"
(( $(grep -c 'ryoku managed colors' "$X/gtk-4.0/gtk.css") == 2 )) || fail "re-run must not duplicate the marker block"
grep -q 'my own tweak' "$X/gtk-4.0/gtk.css" || fail "re-run must keep user content"
bak2="$(sha256sum "$X/gtk-4.0/gtk.css.ryoku-bak" | cut -d' ' -f1)"
[[ $bak1 == "$bak2" ]] || fail "backup must not be re-created on subsequent runs"

# Flag off -> files untouched.
printf '{"services":{"syncAppColors":false}}\n' >"$C/shell.json"
before="$(sha256sum "$X/gtk-4.0/gtk.css" | cut -d' ' -f1)"
run_qt || fail "qtgtk run failed (flag off)"
after="$(sha256sum "$X/gtk-4.0/gtk.css" | cut -d' ' -f1)"
[[ $before == "$after" ]] || fail "syncAppColors=false must leave app config byte-identical"

echo "PASS: app-color-sync"
