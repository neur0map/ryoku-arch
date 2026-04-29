#!/bin/bash
# Brain_Shell Spec 1 smoke test.
# Static checks against the dev tree. Run from repo root.

set -e
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "OK: $1"; }

# --- Snapshot evidence ------------------------------------------------
git rev-parse pre-brainshell-vendor-2026-04-28 >/dev/null 2>&1 \
  || fail "git tag pre-brainshell-vendor-2026-04-28 not found"
ls ~/.local/share/ryoku.pre-brainshell.* >/dev/null 2>&1 \
  || fail "installed-tree backup not found"
pass "snapshots present"

# --- File structure ---------------------------------------------------
[[ -f config/quickshell/ryoku/vendor/brain-shell/LICENSE ]]    || fail "vendored LICENSE missing"
[[ -f config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md ]] || fail "UPSTREAM.md missing"
[[ -d config/quickshell/ryoku/vendor/brain-shell/src/popups ]]  || fail "vendored src/popups missing"
[[ -d config/quickshell/ryoku/vendor/brain-shell/src/windows ]] || fail "vendored src/windows missing"
[[ -f config/quickshell/ryoku/shell.qml ]]                       || fail "shell.qml missing"
[[ -f default/themed/ryoku-shell-colors.json.tpl ]]              || fail "JSON theme template missing"
[[ -f default/themed/quickshell-colors.qml.tpl ]]                || fail "QML theme template missing"
[[ -f CREDITS.md ]]                                              || fail "CREDITS.md missing"
ls migrations/[0-9]*.sh 2>/dev/null | grep -q . \
  || fail "no migration script found in migrations/"
pass "file structure"

# --- shell.qml extends, does not replace ------------------------------
grep -q '^\s*Frame\s*{}' config/quickshell/ryoku/shell.qml \
  || fail "Frame removed from shell.qml (Spec 1 requires it stay)"
grep -q '^\s*ExclusionZones\s*{}' config/quickshell/ryoku/shell.qml \
  || fail "ExclusionZones removed from shell.qml (Spec 1 requires it stay)"
grep -q 'BSW.TopBar' config/quickshell/ryoku/shell.qml \
  || fail "Brain_Shell TopBar not mounted in shell.qml"
grep -q 'BSP.PopupLayer' config/quickshell/ryoku/shell.qml \
  || fail "Brain_Shell PopupLayer not mounted in shell.qml"
pass "shell.qml extension"

# --- Security patches applied -----------------------------------------
grep -q "Ryoku: parse Exec per freedesktop spec" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml \
  || fail "AppLauncher security patch missing"
grep -q "Ryoku: validate gov against allowlist" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml \
  || fail "CpuFreqService security patch missing"
grep -q '"cat", root.configPath' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml \
  || fail "WallpaperService security patch missing"
pass "security patches"

# --- Path rebrands ----------------------------------------------------
! grep -q '/.cache/brain-shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml \
  || fail "ColorLoader still references brain-shell cache path"
! grep -q '/tmp/brain_shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml \
  || fail "CavaService still references brain_shell tmp path"
! grep -q '/tmp/brain_shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml \
  || fail "ScreenRecService still references brain_shell tmp path"
pass "path rebrands"

# --- Theme bridge: rendered JSON is valid and substituted -------------
RENDERED=""
for p in "$HOME/.config/ryoku/current/theme/ryoku-shell-colors.json" \
         "$HOME/.config/ryoku/current/next-theme/ryoku-shell-colors.json"; do
  [[ -f $p ]] && RENDERED="$p" && break
done
if [[ -n $RENDERED ]]; then
  ! grep -q '{{' "$RENDERED" || fail "rendered JSON has unsubstituted placeholders at $RENDERED"
  python3 -c "import json,sys; json.load(open('$RENDERED'))" \
    || fail "rendered JSON malformed at $RENDERED"
  pass "theme bridge"
else
  echo "SKIP: rendered theme colors not found at expected paths (run ryoku-theme-set <theme> first)"
fi

# --- PopupLayer activation matches Reading X --------------------------
ACTIVE=$(grep -cE '^\s*Dashboard\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
DORMANT=$(grep -cE '^\s*//\s*(ArchMenu|WallpaperPopup|AudioPopup|QuickControl|NotificationsPopup|NotificationToast|ScreenRecOptionsPopup|NetworkPopup)\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
[[ $ACTIVE -eq 1 ]]  || fail "expected 1 active popup (Dashboard), got $ACTIVE"
[[ $DORMANT -eq 8 ]] || fail "expected 8 dormant popups, got $DORMANT"
pass "PopupLayer activation matches Reading X"

# --- Dashboard unified shell -----------------------------------------
! grep -q 'TabSwitcher\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard tab bar should be removed"
! grep -q 'property string page:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard page state should be removed"
! grep -q 'DashStats\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not mount DashStats directly"
grep -q 'DashHome\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should mount DashHome"
pass "dashboard unified shell"

# --- Existing stack untouched -----------------------------------------
grep -q "uwsm-app -- waybar" default/hypr/autostart.conf \
  || fail "waybar exec-once was removed (Spec 1 requires it stay)"
grep -q "uwsm-app -- mako" default/hypr/autostart.conf \
  || fail "mako exec-once was removed (Spec 1 requires it stay)"
grep -q "uwsm-app -- swayosd-server" default/hypr/autostart.conf \
  || fail "swayosd exec-once was removed (Spec 1 requires it stay)"
[[ -x bin/tofi && -x bin/tofi-drun ]] \
  || fail "tofi shims were removed (Spec 1 requires they stay)"
[[ -x bin/ryoku-launch-shell ]]  || fail "ryoku-launch-shell removed"
[[ -x bin/ryoku-restart-shell ]] || fail "ryoku-restart-shell removed"
[[ -x bin/ryoku-refresh-quickshell ]] || fail "ryoku-refresh-quickshell removed"
[[ -x bin/ryoku-toggle-frame ]]  || fail "ryoku-toggle-frame removed"
pass "existing stack untouched"

echo ""
echo "Static checks passed. Run the manual checklist next:"
echo "  1. ryoku-refresh-quickshell  (mirror dev tree to ~/.config)"
echo "  2. ryoku-restart-shell       (or run the migration script)"
echo "  3. Visually verify TopBar appears alongside waybar"
echo "  4. Click center notch -> Dashboard opens as one unified home view"
echo "  5. Verify the dashboard has no tab bar and shows home content immediately"
echo "  6. ryoku-theme-set <other-theme> -> colors update across Frame plus TopBar plus Dashboard"
echo "  7. ryoku-toggle-frame -> everything (Frame plus Brain_Shell) disappears"
echo "  8. ryoku-toggle-frame again -> everything comes back"
