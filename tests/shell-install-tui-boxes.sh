#!/bin/bash

# Guards the thing that quietly breaks TUIs: a card whose border does not close
# because its content was mis-measured. Renders the real verdict cards through
# tui_box and asserts every rendered line is the same display width (so the
# rounded border lines up top, bottom, and sides). Without gum, tui_box must
# draw no box at all.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/ui.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/tui.sh"

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

assert_closes() {
  # All non-blank lines of a rendered card share one width, and the frame uses
  # matching rounded corners. ${#line} counts characters in this UTF-8 locale;
  # every glyph the cards use is one cell wide there.
  local card="$1" line first="" last="" width="" n
  while IFS= read -r line; do
    [[ -z ${line//[[:space:]]/} ]] && continue
    n=${#line}
    [[ -z $first ]] && first="$line"
    last="$line"
    if [[ -z $width ]]; then
      width=$n
    elif (( n != width )); then
      fail "card border does not close: line width $n != $width"
    fi
  done < <(printf '%s\n' "$card" | strip_ansi)
  [[ ${first:0:1} == "╭" && ${first: -1} == "╮" ]] || fail "top border is not a closed rounded box"
  [[ ${last:0:1} == "╰" && ${last: -1} == "╯" ]] || fail "bottom border is not a closed rounded box"
}

if tui_has; then
  assert_closes "$(tui_box '#8AB573' '✓  arch  ·  Arch family  ·  supported')"
  assert_closes "$(tui_box '#C75450' \
    '✗  fedora  ·  not an Arch-family distro' '' \
    'The Ryoku shell installer supports the Arch family today' \
    '(Arch, CachyOS, EndeavourOS, Manjaro, Garuda, Artix, ...).' '' \
    'Nothing was changed.')"
  assert_closes "$(tui_box '#F25623' \
    'Recommended: a snapper snapshot before installing, so the system' \
    'packages and drivers can be rolled back if anything goes wrong.')"
  printf 'PASS: tests/shell-install-tui-boxes.sh (gum)\n'
else
  out="$(tui_box X 'one' 'two')"
  printf '%s' "$out" | grep -q '[╭╮╰╯│]' && fail "without gum, tui_box must not draw a box"
  printf 'PASS: tests/shell-install-tui-boxes.sh (fallback)\n'
fi
