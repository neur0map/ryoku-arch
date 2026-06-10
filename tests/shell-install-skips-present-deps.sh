#!/bin/bash

# Proves the standalone dep install is idempotent / smart: it skips packages
# that are already present and only installs what is missing (so re-runs and
# already-provisioned systems do not reinstall or rebuild anything), and never
# installs an @os-only package.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'hyprland\nquickshell\n# @os-only\nsddm\n# @end\n' >"$tmp/base"
printf 'aur-thing\n' >"$tmp/aur"

# Fake sudo/pacman on PATH so install attempts are captured, never executed.
calls="$tmp/calls"
: >"$calls"
mkdir -p "$tmp/bin"
cat >"$tmp/bin/sudo" <<EOF
#!/bin/bash
echo "sudo \$*" >>"$calls"
exit 0
EOF
cat >"$tmp/bin/pacman" <<EOF
#!/bin/bash
# Repo-classify queries (-Si), report the real quickshell as the qs owner
# (-Qoq) so the conflict guard is a no-op here, and log everything else.
if [[ \${1:-} == -Si ]]; then exit 0; fi
if [[ \${1:-} == -Qoq ]]; then printf 'quickshell\n'; exit 0; fi
echo "pacman \$*" >>"$calls"
exit 0
EOF
chmod +x "$tmp/bin/sudo" "$tmp/bin/pacman"
export PATH="$tmp/bin:$PATH"

export HOME="$tmp/home"
mkdir -p "$HOME"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/env.sh"
export RSI_BASE_PACKAGES="$tmp/base"
export RSI_AUR_PACKAGES="$tmp/aur"
export RSI_DRY_RUN=0
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/ui.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/manifest.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/packages.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/distros/arch.sh"

rsi_record() { :; }

# --- Case 1: everything already present -> install nothing at all. ---
rsi_arch_pkg_present() { return 0; }
out1="$(ryoku_distro_install_full 2>&1)"
grep -q "all Ryoku packages already present" <<<"$out1" \
  || fail "all-present run must report nothing to install"
[[ ! -s $calls ]] \
  || fail "all-present run must not invoke pacman/sudo (got: $(cat "$calls"))"

# --- Case 2: hyprland present, the rest missing -> install only the missing. ---
: >"$calls"
rsi_arch_pkg_present() { [[ $1 == hyprland ]]; }
ryoku_distro_install_full >/dev/null 2>&1
got="$(cat "$calls")"

grep -q 'pacman -S --needed' <<<"$got" || fail "missing packages must install with --needed"
grep -q 'quickshell' <<<"$got" || fail "missing package quickshell must be installed"
grep -qw 'hyprland' <<<"$got" && fail "already-present hyprland must NOT be reinstalled"
grep -qw 'sddm' <<<"$got" && fail "@os-only sddm must never be installed by the standalone"

printf 'PASS: tests/shell-install-skips-present-deps.sh\n'
