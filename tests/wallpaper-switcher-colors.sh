#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

for f in bin/ryoku-cmd-wallpaper-switcher shell/scripts/ryoku migrations/1780317571.sh; do
  bash -n "$ROOT_DIR/$f" || fail "$f has a syntax error"
done

# 1. skwd must not prewarm its own skwd-paper layer: paper.engine off skwd-paper.
jq -e '.paper.engine == "awww"' "$ROOT_DIR/config/skwd-wall/config.json" >/dev/null \
  || fail "config/skwd-wall/config.json must set paper.engine=awww (else skwd-daemon prewarms a competing skwd-paper layer and grey-flashes Super+W)"

# 2. The Super+W switcher must gate on real daemon readiness, not socket existence.
rg -q 'skwd wall list' "$ROOT_DIR/bin/ryoku-cmd-wallpaper-switcher" \
  || fail "ryoku-cmd-wallpaper-switcher must poll 'skwd wall list' for readiness (socket existence is not readiness)"

# 3. The wallpaper scheme flow must also regenerate the dashboard named-accent palette.
rg -q 'generate_dashboard_colors\(\)' "$ROOT_DIR/shell/scripts/ryoku" \
  || fail "shell/scripts/ryoku must define generate_dashboard_colors"
rg -q 'generate_dashboard_colors "' "$ROOT_DIR/shell/scripts/ryoku" \
  || fail "apply_wallpaper_scheme must call generate_dashboard_colors so named accents follow the wallpaper"
rg -q 'assets/matugen/config.toml' "$ROOT_DIR/shell/scripts/ryoku" \
  || fail "generate_dashboard_colors must drive matugen with the dashboard config.toml"

# 4. Migration behaviour: sandbox with stubbed matugen/systemctl/pkill (never touch the real daemon).
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/skwd-wall" "$tmp/state/ryoku-shell/wallpaper" \
  "$tmp/config/ryoku/current" "$tmp/rp/shell/dashboard/assets/matugen" "$tmp/bin"

printf '{"pickOnlyMode":true,"paper":{"engine":"skwd-paper"}}\n' >"$tmp/config/skwd-wall/config.json"
printf '%s\n' "$tmp/wall.png" >"$tmp/state/ryoku-shell/wallpaper/path.txt"
printf 'image\n' >"$tmp/state/ryoku-shell/wallpaper/type.txt"
printf '{"mode":"dark","colours":{}}\n' >"$tmp/state/ryoku-shell/scheme.json"
: >"$tmp/wall.png"
printf '[templates.dashboard]\n' >"$tmp/rp/shell/dashboard/assets/matugen/config.toml"

cat >"$tmp/bin/matugen" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$tmp/matugen-args"
EOF
# Stub the side-effecting commands so the test can never restart/kill the real daemon.
printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/systemctl"
printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/pkill"
chmod +x "$tmp/bin/matugen" "$tmp/bin/systemctl" "$tmp/bin/pkill"

XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" RYOKU_PATH="$tmp/rp" \
  PATH="$tmp/bin:$PATH" bash "$ROOT_DIR/migrations/1780317571.sh" >/dev/null 2>&1

[[ "$(jq -r '.paper.engine' "$tmp/config/skwd-wall/config.json")" == "awww" ]] \
  || fail "migration did not set live paper.engine=awww"
[[ -f "$tmp/matugen-args" ]] || fail "migration did not invoke matugen to regenerate colors.json"
grep -q -- '-t scheme-tonal-spot' "$tmp/matugen-args" || fail "migration matugen call missing the tonal-spot scheme"
grep -q -- '--mode dark' "$tmp/matugen-args" || fail "migration matugen call did not use the scheme mode"

echo "PASS: skwd engine=awww, switcher readiness probe, and wallpaper->dashboard colour regen are wired"
