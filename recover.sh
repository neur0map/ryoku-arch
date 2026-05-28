#!/bin/bash
#
# Ryoku MedEvac online recovery bootstrap.
#
#   curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/recover.sh | bash
#   # or, to pin a channel:
#   curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/unstable-dev/recover.sh | RYOKU_REF=unstable-dev bash
#
# This is the LAST RESORT, for when the local install is too broken to run
# `ryoku-call911now` at all (wiped or corrupted checkout, missing bin, dead git
# repo, etc.). It depends on nothing local: it installs the minimum rescue
# tools, fetches a FRESH official checkout (preserving whatever was there), then
# hands off to that fresh checkout's MedEvac to finish the repair (command
# bridges, hyprland.conf, doctor, update). Requires an internet connection.
#
# Overridable env: RYOKU_REPO (default neur0map/ryoku-arch), RYOKU_REF
# (channel: main | unstable-dev), RYOKU_PATH (default ~/.local/share/ryoku).

set -euo pipefail

REPO="${RYOKU_REPO:-neur0map/ryoku-arch}"
REMOTE="${RYOKU_REMOTE:-https://github.com/${REPO}.git}"
RYOKU_PATH="${RYOKU_PATH:-$HOME/.local/share/ryoku}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku"

c_accent=$'\033[36m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_ok=$'\033[32m'; c_off=$'\033[0m'
[[ -t 1 ]] || { c_accent=""; c_warn=""; c_err=""; c_ok=""; c_off=""; }
log()  { printf '%s==>%s %s\n' "$c_accent" "$c_off" "$*"; }
ok()   { printf '%sOK:%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%sWARN:%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
die()  { printf '%sERROR:%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }

log "Ryoku MedEvac online recovery"

# 1. Resolve the recovery channel: explicit RYOKU_REF, else the persisted
#    channel, else unstable-dev. Anything unrecognized falls back to a valid one.
ref="${RYOKU_REF:-}"
if [[ -z $ref && -r "$STATE_DIR/channel" ]]; then
  ref="$(tr -d '[:space:]' < "$STATE_DIR/channel" 2>/dev/null || true)"
fi
case "$ref" in
  main | unstable-dev) ;;
  *) ref="unstable-dev" ;;
esac
log "Recovery channel: $ref"

# 2. Ensure the minimum rescue tools exist.
need=()
command -v git >/dev/null 2>&1 || need+=(git)
{ command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; } || need+=(curl)
if ((${#need[@]} > 0)); then
  log "Installing rescue tools: ${need[*]}"
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed --noconfirm "${need[@]}" || die "could not install ${need[*]}"
    hash -r 2>/dev/null || true
  else
    die "missing ${need[*]} and pacman is unavailable to install them"
  fi
fi

# 3. Fetch a fresh checkout into a throwaway temp dir (so a failed/partial fetch
#    never touches the live install). Prefer git; fall back to a tarball.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fresh="$tmp/ryoku"

if command -v git >/dev/null 2>&1; then
  log "Cloning fresh '$ref' checkout from $REMOTE"
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true \
    git clone --branch "$ref" "$REMOTE" "$fresh" \
    || die "git clone failed - check your internet connection, then retry"
else
  command -v tar >/dev/null 2>&1 || die "no git and no tar available to fetch a checkout"
  log "git unavailable; downloading '$ref' archive"
  arc="$tmp/ryoku.tar.gz"
  url="https://github.com/${REPO}/archive/refs/heads/${ref}.tar.gz"
  { command -v curl >/dev/null 2>&1 && curl -fsSL "$url" -o "$arc"; } \
    || { command -v wget >/dev/null 2>&1 && wget -qO "$arc" "$url"; } \
    || die "could not download $url"
  tar -xzf "$arc" -C "$tmp" || die "could not unpack the downloaded archive"
  fresh="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -name 'ryoku-arch-*' | head -n 1)"
  [[ -n $fresh ]] || die "downloaded archive did not contain a Ryoku checkout"
fi
[[ -d $fresh ]] || die "fresh checkout was not produced"
ok "Fetched a fresh checkout"

# 4. Atomically swap it into place, preserving any existing install.
mkdir -p "$(dirname "$RYOKU_PATH")"
if [[ -e $RYOKU_PATH || -L $RYOKU_PATH ]]; then
  backup="$STATE_DIR/medevac-backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup"
  mv -- "$RYOKU_PATH" "$backup/$(basename "$RYOKU_PATH")" \
    && warn "preserved the previous checkout at $backup/$(basename "$RYOKU_PATH")"
fi
mv -- "$fresh" "$RYOKU_PATH"
trap - EXIT
rm -rf "$tmp"
ok "Installed fresh checkout at $RYOKU_PATH"

# 5. Hand off to the fresh MedEvac to finish the repair (bridges, hyprland.conf,
#    doctor, update). Re-attach stdin to the terminal so its prompts work even
#    though this script arrived over a pipe (curl | bash).
medevac="$RYOKU_PATH/bin/ryoku-call911now"
export RYOKU_PATH

# Re-attach stdin to the controlling terminal so MedEvac's prompts work even
# though this script arrived over a pipe (curl | bash) - but only if /dev/tty
# is actually OPENABLE (it can exist yet be unopenable with no controlling tty).
reattach=""
if { : < /dev/tty; } 2>/dev/null; then
  reattach="/dev/tty"
fi
run() {
  if [[ -n $reattach ]]; then
    exec "$@" <"$reattach"
  fi
  exec "$@"
}

log "Handing off to MedEvac for full repair"
if [[ -x $medevac ]]; then
  run "$medevac"
elif [[ -f $medevac ]]; then
  run bash "$medevac"
elif [[ -f $RYOKU_PATH/install.sh ]]; then
  warn "fresh checkout has no MedEvac; running the installer instead"
  run bash "$RYOKU_PATH/install.sh"
else
  die "fresh checkout has no recovery entry point (bin/ryoku-call911now)"
fi
