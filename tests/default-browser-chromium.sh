#!/bin/bash
# Guards the Helium -> Chromium default-browser swap. Helium runs under XWayland
# (so it cannot screen-share native Wayland windows); Chromium runs on Wayland and
# drives the PipeWire screencast portal. This checks fresh installs, the installer,
# mimetypes, the SUPER+B keybind, and the migrator -- and functionally proves the
# migrator switches a Helium default to Chromium while leaving a browser the user
# deliberately chose untouched.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# ── 1. fresh install gets Chromium from the package manifest (no install script) ─
grep -Eq '^chromium$' "$ROOT/install/ryoku-base.packages" \
  || fail "chromium must be listed in the base package manifest"
[[ ! -e $ROOT/install/config/chromium-browser.sh ]] \
  || fail "chromium is a package; it needs no install/config script"
grep -q 'chromium-browser.sh' "$ROOT/install/config/all.sh" \
  && fail "all.sh must not reference a chromium install script"
grep -q 'helium-browser.sh' "$ROOT/install/config/all.sh" \
  && fail "all.sh must not run the removed helium-browser.sh"

# ── 2. no dedicated install command: a plain package goes through ryoku-pkg-add ─
[[ ! -e $ROOT/bin/ryoku-install-chromium-browser ]] \
  || fail "chromium is a package; it must not need a dedicated ryoku-install-* command"
grep -q 'install_package="chromium"' "$ROOT/bin/ryoku-default-app-migrate" \
  || fail "migrator must install chromium via install_package (ryoku-pkg-add), not a custom command"

# ── 3. mimetypes default ──────────────────────────────────────────────────────
grep -q 'default-web-browser chromium.desktop' "$ROOT/install/config/mimetypes.sh" \
  || fail "mimetypes.sh must set chromium as the default browser"
grep -q 'default-web-browser helium.desktop' "$ROOT/install/config/mimetypes.sh" \
  && fail "mimetypes.sh must not set helium as the default browser"

# ── 4. keybind + var ──────────────────────────────────────────────────────────
grep -q 'local var_browser = "chromium"' "$ROOT/config/hypr/hyprland.lua" \
  || fail "hyprland.lua must define var_browser = chromium"
grep -Eq 'SUPER \+ B".*var_browser' "$ROOT/config/hypr/hyprland.lua" \
  || fail "SUPER+B must launch var_browser"
grep -q 'var_heliumBrowser' "$ROOT/config/hypr/hyprland.lua" \
  && fail "stale var_heliumBrowser is still referenced in hyprland.lua"

# ── 5. migrator supports the chromium target ──────────────────────────────────
grep -q 'browser:chromium)' "$ROOT/bin/ryoku-default-app-migrate" \
  || fail "migrator is missing the browser:chromium spec"

# ── 6. migration invokes it ───────────────────────────────────────────────────
grep -q 'ryoku-default-app-migrate browser chromium' "$ROOT/migrations/1781360776.sh" \
  || fail "migration must invoke the chromium browser migration"

# ── 7. functional: Helium default -> Chromium; deliberate choice preserved ─────
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
# Stateful xdg-settings stub backed by a file so we can assert the resulting default.
cat >"$WORK/bin/xdg-settings" <<'EOF'
#!/bin/bash
state="$XDG_TEST_STATE"
case "$1" in
  get) cat "$state" 2>/dev/null || true ;;
  set) printf '%s' "$3" > "$state" ;;
esac
exit 0
EOF
for c in xdg-mime ryoku-cmd-present ryoku-tui; do
  printf '#!/bin/bash\nexit 0\n' >"$WORK/bin/$c"
done
# ryoku-pkg-add stub: pretend the install succeeds and makes chromium available,
# so the migrator's post-install presence check passes and it proceeds to switch.
cat >"$WORK/bin/ryoku-pkg-add" <<'EOF'
#!/bin/bash
printf '#!/bin/bash\nexit 0\n' > "$(dirname "$0")/chromium"
chmod +x "$(dirname "$0")/chromium"
exit 0
EOF
chmod +x "$WORK"/bin/*

run_migrate() {
  HOME="$WORK" XDG_CONFIG_HOME="$WORK/.config" XDG_TEST_STATE="$WORK/default-browser" \
    PATH="$WORK/bin:$PATH" bash "$ROOT/bin/ryoku-default-app-migrate" browser chromium yes >/dev/null 2>&1
}

printf 'helium.desktop' >"$WORK/default-browser"
run_migrate || fail "migrator run failed for a Helium default"
[[ "$(cat "$WORK/default-browser")" == "chromium.desktop" ]] \
  || fail "migrator must switch a Helium default to Chromium (got '$(cat "$WORK/default-browser")')"

printf 'brave-browser.desktop' >"$WORK/default-browser"
run_migrate || fail "migrator run failed for a Brave default"
[[ "$(cat "$WORK/default-browser")" == "brave-browser.desktop" ]] \
  || fail "migrator must NOT override a deliberate non-Ryoku default (got '$(cat "$WORK/default-browser")')"

echo "PASS: default-browser-chromium"
