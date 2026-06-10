#!/bin/bash

# Proves the standalone resolves a conflicting quickshell provider. A CachyOS
# Niri+Noctalia base ships noctalia-qs, which provides AND conflicts quickshell
# and owns /usr/bin/qs, so the manifest's `quickshell` looks already-satisfied
# and the shell ends up on an incompatible qs (black screen). The fix must
# replace the conflicting owner with the real quickshell, no-op when the real
# package already owns qs, and install (without removing) when none is present.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

calls="$tmp/calls"
: >"$calls"
mkdir -p "$tmp/bin"

# Fake pacman: `-Qoq /usr/bin/qs` reports $QS_OWNER; nothing is ever installed.
cat >"$tmp/bin/pacman" <<EOF
#!/bin/bash
[[ \${1:-} == -Qoq ]] && { printf '%s\n' "\${QS_OWNER:-}"; exit 0; }
echo "pacman \$*" >>"$calls"
exit 0
EOF
# Fake sudo logs the command and succeeds, so install attempts are captured.
cat >"$tmp/bin/sudo" <<EOF
#!/bin/bash
echo "sudo \$*" >>"$calls"
exit 0
EOF
chmod +x "$tmp/bin/pacman" "$tmp/bin/sudo"
export PATH="$tmp/bin:$PATH"

export HOME="$tmp/home"
mkdir -p "$HOME"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/env.sh"
export RSI_DRY_RUN=0
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/ui.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/distros/arch.sh"

rsi_record() { :; }

# --- Case 1: a conflicting provider owns qs -> remove it, install the real one.
: >"$calls"
QS_OWNER=noctalia-qs rsi_arch_ensure_real_quickshell >/dev/null 2>&1
got="$(cat "$calls")"
grep -q 'pacman -Rdd --noconfirm noctalia-qs' <<<"$got" \
  || fail "must remove the conflicting provider noctalia-qs (got: $got)"
grep -q 'pacman -S --needed --noconfirm quickshell' <<<"$got" \
  || fail "must install the real quickshell (got: $got)"

# --- Case 2: the real quickshell already owns qs -> do nothing.
: >"$calls"
QS_OWNER=quickshell rsi_arch_ensure_real_quickshell >/dev/null 2>&1
[[ ! -s $calls ]] \
  || fail "must not touch a system already on the real quickshell (got: $(cat "$calls"))"

# --- Case 3: nothing owns qs (fresh) -> install, but remove nothing.
: >"$calls"
QS_OWNER='' rsi_arch_ensure_real_quickshell >/dev/null 2>&1
got="$(cat "$calls")"
grep -q 'pacman -S --needed --noconfirm quickshell' <<<"$got" \
  || fail "must install quickshell when none is present (got: $got)"
grep -q 'pacman -Rdd' <<<"$got" \
  && fail "must not remove anything when no provider owns qs (got: $got)"

printf 'PASS: tests/shell-install-quickshell-conflict.sh\n'
