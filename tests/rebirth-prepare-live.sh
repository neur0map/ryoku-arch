#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PREP="$ROOT_DIR/bin/ryoku-rebirth-prepare-live"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -x $PREP ]] || fail "missing executable prepare command"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/state"

cat > "$tmp_dir/bin/ryoku-pkg-present" <<'SH'
#!/bin/bash
case "$1" in
  xdg-desktop-portal|xdg-desktop-portal-gtk|qt6-wayland)
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
SH

cat > "$tmp_dir/bin/ryoku-pkg-add" <<'SH'
#!/bin/bash
printf '%s\n' "$*" > "$RYOKU_TEST_STATE/pkg-add.args"
SH

cat > "$tmp_dir/bin/sudo" <<'SH'
#!/bin/bash
if [[ $1 == "-n" && $2 == "true" ]]; then
  exit "${RYOKU_TEST_SUDO_STATUS:-1}"
fi
exit 1
SH

chmod +x "$tmp_dir/bin/"*

export PATH="$tmp_dir/bin:/usr/bin"
export RYOKU_TEST_STATE="$tmp_dir/state"

dry_output=$("$PREP" --dry-run)

for package in aubio hyprland qt5-wayland qt6-wayland ttf-cascadia-code-nerd xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland app2unit; do
  grep -Eq "(present|missing): $package" <<<"$dry_output" || \
    fail "dry-run output should list $package"
done

set +e
"$PREP" >"$tmp_dir/no-auth.out" 2>"$tmp_dir/no-auth.err"
status=$?
set -e

(( status == 77 )) || fail "prepare command should refuse non-interactive root auth"
[[ ! -f $tmp_dir/state/pkg-add.args ]] || fail "prepare command should not install without auth"
grep -Fq -- "--allow-auth-prompt" "$tmp_dir/no-auth.err" || \
  fail "prepare command should print the interactive retry command"

export RYOKU_TEST_SUDO_STATUS=0
"$PREP" >"$tmp_dir/auth.out"

[[ -f $tmp_dir/state/pkg-add.args ]] || fail "prepare command should call ryoku-pkg-add when auth is available"
grep -Fq "aubio hyprland qt5-wayland ttf-cascadia-code-nerd xdg-desktop-portal-hyprland app2unit" "$tmp_dir/state/pkg-add.args" || \
  fail "prepare command should install only missing packages"
! grep -Fq "niri" "$tmp_dir/state/pkg-add.args" || \
  fail "prepare command should never remove or install Niri"

echo "PASS: rebirth live preparation is guarded and keeps apps intact"
