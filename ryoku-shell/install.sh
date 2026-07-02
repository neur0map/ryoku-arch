#!/usr/bin/env bash
#
# ryoku-shell bootstrap: fetch and run the standalone Ryoku desktop installer
# on an existing Arch machine. Kept deliberately dumb: every real decision
# lives in the ryoku-shell-install binary this script downloads.
#
#   curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/ryoku-shell/install.sh | bash
#
# args after `bash -s --` are forwarded to the installer (--yes, --dry-run).
# RYOKU_SHELL_REF picks the git ref to fetch the installer and payload from.
set -euo pipefail

main() {
  local ref="${RYOKU_SHELL_REF:-main}"
  local raw="https://raw.githubusercontent.com/neur0map/ryoku-arch/${ref}/ryoku-shell"

  say() { printf '\033[38;2;242;86;35m==>\033[0m %s\n' "$*"; }
  die() {
    printf 'ryoku-shell: %s\n' "$*" >&2
    exit 1
  }

  [[ $(id -u) -ne 0 ]] || die "run as your normal user, not root (sudo is used when needed)"
  command -v pacman > /dev/null 2>&1 || die "this installer needs an Arch-based system (pacman not found)"
  [[ $(uname -m) == x86_64 ]] || die "the [ryoku] repository ships x86_64 packages only"
  command -v curl > /dev/null 2>&1 || die "curl is required"

  # warn-only on unusual derivatives: pacman presence is what actually matters.
  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-} ${ID_LIKE:-}" in
      *arch*) ;;
      *) say "warning: ${PRETTY_NAME:-unknown distro} is not Arch; continuing because pacman exists" ;;
    esac
  fi

  local work
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT

  say "fetching the Ryoku shell installer (${ref})"
  curl -fsSL --retry 3 -o "$work/ryoku-shell-install" "$raw/ryoku-shell-install"
  curl -fsSL --retry 3 -o "$work/ryoku-shell-install.sha256" "$raw/ryoku-shell-install.sha256"
  (cd "$work" && sha256sum --check --quiet ryoku-shell-install.sha256) \
    || die "checksum mismatch on the downloaded installer; try again"
  chmod +x "$work/ryoku-shell-install"

  say "starting the installer"
  local rc=0
  # piped stdin (curl | bash) is useless to a TUI; hand it the real terminal.
  if [[ ! -t 0 && -r /dev/tty ]]; then
    RYOKU_SHELL_REF="$ref" "$work/ryoku-shell-install" "$@" < /dev/tty || rc=$?
  else
    RYOKU_SHELL_REF="$ref" "$work/ryoku-shell-install" "$@" || rc=$?
  fi
  return "$rc"
}

main "$@"
