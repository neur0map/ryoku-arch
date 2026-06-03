#!/bin/bash
# Guards against the "fresh install halts in the chroot" class.
#
# install.sh runs preflight/packaging/config/login/post-install entirely inside
# the arch-chroot install (install_ryoku -> chroot_bash -> install.sh), where
# there is NO user-session bus. A bare `systemctl --user enable|start|...` there
# fails ("Failed to connect to user scope bus"); run_logged executes each script
# in a `set -e` subshell, so that non-zero return trips install.sh's ERR trap and
# HALTS the whole install before login/ (SDDM + qylock) and post-install/ ever
# run. That is exactly the regression that left fresh ISO installs without the
# qylock greeter (and other login/post-install wiring).
#
# Rule: any mutating `systemctl --user` call in a chroot-run install phase MUST
# be guarded with `|| true` (it no-ops in the chroot; the real enablement comes
# from install/preflight/ensure-shell-deployment.sh, which recreates the
# [Install] wants-links chroot-safely). Scripts under install/first-run/ are
# exempt: they run in the user session at first boot, where the bus exists.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Chroot-run install phases (NOT first-run/, which runs in the user session).
dirs=()
for d in preflight packaging config login post-install; do
  [[ -d $ROOT_DIR/install/$d ]] && dirs+=("$ROOT_DIR/install/$d")
done
[[ ${#dirs[@]} -gt 0 ]] || fail "no chroot-run install phase directories found under install/"

# Mutating verbs (state changes that need a manager/bus); daemon-reload first so
# the alternation matches it before the shorter 'reload'.
verbs='daemon-reload|reload|enable|disable|start|stop|restart|mask|unmask'

matches="$(grep -rnE "systemctl --user ($verbs)" "${dirs[@]}" 2>/dev/null || true)"
[[ -n $matches ]] || fail "found no 'systemctl --user' calls to check (regex/layout drift?)"

violations=""
checked=0
while IFS= read -r line; do
  [[ -z $line ]] && continue
  file="${line%%:*}"; rest="${line#*:}"; lineno="${rest%%:*}"; content="${rest#*:}"
  trimmed="${content#"${content%%[![:space:]]*}"}"   # left-trim
  # Skip comments.
  [[ $trimmed == \#* ]] && continue
  # Skip conditionals: the if/while construct already handles a non-zero status.
  case "$trimmed" in
    if\ *|elif\ *|while\ *|until\ *|"&& "*|"|| "*) continue ;;
  esac
  # Skip read-only/query verbs (they may appear inside conditions on their own line).
  if printf '%s' "$content" | grep -qE 'systemctl --user (is-active|is-enabled|is-failed|is-system-running|show|status|list-|cat|get-default)'; then
    continue
  fi
  checked=$((checked + 1))
  # Guarded with `|| true` / `|| :` is the required pattern.
  if printf '%s' "$content" | grep -qE '\|\|[[:space:]]*(true|:)([[:space:]]|$)'; then
    continue
  fi
  rel="${file#"$ROOT_DIR/"}"
  violations+="  $rel:$lineno: $trimmed"$'\n'
done <<< "$matches"

if [[ -n $violations ]]; then
  echo "FAIL: unguarded mutating 'systemctl --user' in a chroot-run install phase." >&2
  echo "These fail in the arch-chroot (no user bus) and halt the whole install." >&2
  echo "Guard each with '>/dev/null 2>&1 || true' (see install/config/ryoku-hypridle.sh)" >&2
  echo "and rely on ensure-shell-deployment.sh for the real wants-link:" >&2
  printf '%s' "$violations" >&2
  exit 1
fi

echo "OK: $checked mutating 'systemctl --user' call(s) in chroot-run phases are all guarded."
