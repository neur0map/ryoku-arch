#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_contains() {
  local file="$1" pat="$2" msg="$3"
  grep -Eq "$pat" "$file" || fail "$msg ($file should match: $pat)"
}

SYNC="bin/ryoku-keymap-sync"
[[ -x $SYNC ]] || fail "ryoku-keymap-sync should be executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Self-contained kbd-model-map fixture so the test does not depend on the host's
# systemd. Columns: console-keymap xlayout xmodel xvariant xoptions.
make_root() {
  local km="$1" root="$tmp/r"
  rm -rf "$root"
  mkdir -p "$root/etc" "$root/usr/share/systemd"
  printf 'KEYMAP=%s\nFONT=default8x16\n' "$km" >"$root/etc/vconsole.conf"
  cat >"$root/usr/share/systemd/kbd-model-map" <<'MAP'
us	us	pc105+inet	-	terminate:ctrl_alt_bksp
de	de	pc105	-	terminate:ctrl_alt_bksp
dk-latin1	dk	pc105	-	terminate:ctrl_alt_bksp
fr_CH	ch	pc105	fr	terminate:ctrl_alt_bksp
sv-latin1	se	pc105	-	terminate:ctrl_alt_bksp
MAP
  printf '%s\n' "$root"
}

layout_of() { sed -n -E 's/.*"XkbLayout" "([^"]*)".*/\1/p' "$1/etc/X11/xorg.conf.d/00-keyboard.conf" 2>/dev/null; }
variant_of() { sed -n -E 's/.*"XkbVariant" "([^"]*)".*/\1/p' "$1/etc/X11/xorg.conf.d/00-keyboard.conf" 2>/dev/null; }

# 1. kbd-model-map conversions (the SDDM greeter must read the same layout the
#    disk-unlock prompt and TTY use, or non-US passwords are rejected).
for pair in "de:de" "dk-latin1:dk" "sv-latin1:se"; do
  km="${pair%%:*}"; want="${pair##*:}"
  root="$(make_root "$km")"
  "$SYNC" --root "$root" --quiet
  got="$(layout_of "$root")"
  [[ $got == "$want" ]] || fail "console keymap '$km' should map to X11 layout '$want', got '$got'"
  assert_contains "$root/etc/vconsole.conf" "^XKBLAYOUT=\"$want\"" "vconsole.conf should record XKBLAYOUT for '$km' (so Hyprland inherits it)"
done

# 2. Layout + variant is preserved (fr_CH -> ch/fr; wrong variant = wrong chars).
root="$(make_root fr_CH)"
"$SYNC" --root "$root" --quiet
[[ $(layout_of "$root") == "ch" ]] || fail "fr_CH should map to X11 layout 'ch'"
[[ $(variant_of "$root") == "fr" ]] || fail "fr_CH should map to X11 variant 'fr'"

# 3. Built-in supplement covers layouts systemd's map omits (no kbd-model-map row).
for pair in "cz:cz" "pl:pl" "no-latin1:no"; do
  km="${pair%%:*}"; want="${pair##*:}"
  root="$(make_root "$km")"
  : >"$root/usr/share/systemd/kbd-model-map"   # force the supplement path
  "$SYNC" --root "$root" --quiet
  got="$(layout_of "$root")"
  [[ $got == "$want" ]] || fail "supplement: console keymap '$km' should map to '$want', got '$got'"
done

# 4. us layout is the default: no config written, us users are unaffected.
root="$(make_root us)"
"$SYNC" --root "$root" --quiet
[[ ! -f $root/etc/X11/xorg.conf.d/00-keyboard.conf ]] || fail "us keymap should be a no-op (no X11 config written)"

# 5. Unknown keymap must not regress: leave the greeter keymap untouched.
root="$(make_root bogus-xyz)"
: >"$root/usr/share/systemd/kbd-model-map"
"$SYNC" --root "$root" --quiet
[[ ! -f $root/etc/X11/xorg.conf.d/00-keyboard.conf ]] || fail "unknown keymap should not write an X11 config"

# 6. The actual bug condition (X11 stuck at us while console is non-us) is fixed.
root="$(make_root de)"
mkdir -p "$root/etc/X11/xorg.conf.d"
printf 'Option "XkbLayout" "us"\n' >"$root/etc/X11/xorg.conf.d/00-keyboard.conf"
"$SYNC" --root "$root" --quiet
[[ $(layout_of "$root") == "de" ]] || fail "a us X11 layout with a non-us console keymap should be repaired to 'de'"

# 7. A deliberate, different non-us X11 layout is never clobbered without --force.
root="$(make_root de)"
mkdir -p "$root/etc/X11/xorg.conf.d"
printf 'Option "XkbLayout" "fr"\n' >"$root/etc/X11/xorg.conf.d/00-keyboard.conf"
"$SYNC" --root "$root" --quiet || true
[[ $(layout_of "$root") == "fr" ]] || fail "a deliberate non-us X11 layout must not be overwritten without --force"
"$SYNC" --root "$root" --quiet --force
[[ $(layout_of "$root") == "de" ]] || fail "--force should override the X11 layout to match the console keymap"

# 7b. Every console keymap the installer offers must resolve to an X11 layout,
#     or that user lands right back in the us-greeter bug. Guards against adding
#     a keymap to the configurator without a mapping. Needs systemd's table.
if [[ -f /usr/share/systemd/kbd-model-map ]]; then
  configurator="iso/configs/airootfs/root/configurator"
  mapfile -t offered < <(
    sed -n "/keyboards=\$'/,/'\$/p" "$configurator" | grep '|' | sed -e 's/.*|//' -e "s/'\$//"
  )
  (( ${#offered[@]} > 0 )) || fail "could not read the configurator keymap list"
  for km in "${offered[@]}"; do
    [[ -n $km ]] || continue
    cov="$tmp/cov"; rm -rf "$cov"; mkdir -p "$cov/etc"
    printf 'KEYMAP=%s\n' "$km" >"$cov/etc/vconsole.conf"
    if "$SYNC" --root "$cov" --quiet </dev/null 2>&1 >/dev/null | grep -q 'could not map'; then
      fail "installer keymap '$km' does not resolve to an X11 layout (greeter would fall back to us)"
    fi
  done
fi

# 8. Wiring: install seeds it before Hyprland layout detection; migration + the
#    TTY recovery command both repair existing installs.
assert_contains install/config/all.sh 'sync-greeter-keymap\.sh' "install should run the greeter keymap sync step"
all_sync="$(grep -n 'sync-greeter-keymap.sh' install/config/all.sh | head -1 | cut -d: -f1)"
all_detect="$(grep -n 'detect-keyboard-layout.sh' install/config/all.sh | head -1 | cut -d: -f1)"
(( all_sync < all_detect )) || fail "sync-greeter-keymap.sh should run before detect-keyboard-layout.sh"
assert_contains install/config/sync-greeter-keymap.sh 'ryoku-keymap-sync' "install step should invoke ryoku-keymap-sync"
assert_contains migrations/1781147236.sh 'ryoku-keymap-sync' "migration should run ryoku-keymap-sync for existing installs"
assert_contains bin/ryoku-call911now 'ryoku-keymap-sync' "ryoku-call911now should repair the greeter keymap from a TTY"

echo "PASS: tests/greeter-keymap-sync.sh"
