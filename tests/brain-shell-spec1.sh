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

# --- PopupLayer scope -------------------------------------------------
ACTIVE=$(grep -cE '^\s*(ArchMenu|WallpaperPopup|AudioPopup|QuickControl|NotificationsPopup|NotificationToast|ScreenRecOptionsPopup|NetworkPopup)\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml || true)
DORMANT=$(grep -cE '^\s*//\s*(ArchMenu|WallpaperPopup|AudioPopup|QuickControl|NotificationsPopup|NotificationToast|ScreenRecOptionsPopup|NetworkPopup)\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
! grep -q '^\s*Dashboard\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml \
  || fail "PopupLayer should not instantiate Dashboard after drawer integration"
[[ $ACTIVE -eq 0 ]]  || fail "expected 0 active popups in PopupLayer, got $ACTIVE"
[[ $DORMANT -eq 8 ]] || fail "expected 8 dormant popups, got $DORMANT"
pass "PopupLayer scope"

# --- Dormant network popup has no live right-bar triggers -------------
grep -q '^\s*//\s*NetworkPopup\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml \
  || fail "NetworkPopup should remain dormant in PopupLayer"
! grep -q 'Popups\.networkOpen = true' \
  config/quickshell/ryoku/vendor/brain-shell/src/modules/Right/Network.qml \
  || fail "Right bar should not open dormant NetworkPopup"
! grep -q 'Popups\.networkPage =' \
  config/quickshell/ryoku/vendor/brain-shell/src/modules/Right/Network.qml \
  || fail "Right bar should not target dormant network popup pages"
pass "dormant network popup has no live right-bar triggers"

# --- Dashboard unified shell -----------------------------------------
grep -q 'Dashboard\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "TopBar should mount the integrated dashboard drawer"
! grep -q 'TabSwitcher\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard tab bar should be removed"
! grep -q 'property string page:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard page state should be removed"
! grep -q 'DashStats\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not mount DashStats directly"
! grep -q 'PanelWindow\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should no longer be a detached PanelWindow"
! grep -q 'required property var anchorWindow' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not require an external anchor window"
grep -q 'property:\s*"dashboardPageWidth"' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should bind Popups.dashboardPageWidth"
grep -q 'value:\s*Theme\.dashboardWidth' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should sync Popups.dashboardPageWidth to Theme.dashboardWidth"
grep -q 'DashHome\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should mount DashHome"
pass "dashboard unified shell"

# --- Dashboard motion -------------------------------------------------
grep -q 'property real offsetScale:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should use a single scalar offsetScale"
! grep -q 'property real openProgress:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not use detached popup openProgress motion anymore"
! grep -q 'property real shellProgress:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not keep a separate shellProgress timeline"
! grep -q 'property real contentProgress:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not keep a separate contentProgress timeline"
grep -q 'Behavior on offsetScale' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should animate offsetScale like an integrated drawer"
! grep -q 'Component\.onCompleted:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not need popup window visibility bootstrap"
python3 - <<'PY' || fail "Dashboard motion should be drawer-style and geometry-stable"
import pathlib
import re
import sys

dashboard = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml").read_text()

def grab(pattern, label):
    m = re.search(pattern, dashboard)
    if not m:
        print(f"missing {label}", file=sys.stderr)
        sys.exit(1)
    return int(m.group(1))

motion_duration = grab(r'readonly property int motionDuration:\s*Math\.max\(([0-9]+),', "motionDuration")

if motion_duration < 340:
    print(f"motionDuration floor {motion_duration} is too fast", file=sys.stderr)
    sys.exit(1)

required_literals = [
    'readonly property real revealedHeight:',
    'readonly property real panelHeight:',
    'height: Theme.notchHeight + root.revealedHeight',
    'opacity: 1 - root.offsetScale',
    'clip: true',
    'topMargin:    Theme.notchHeight + 8',
]

for literal in required_literals:
    if literal not in dashboard:
        print(f"missing {literal}", file=sys.stderr)
        sys.exit(1)

for forbidden in [
    "PanelWindow",
    "WlrLayershell.layer",
    "shellProgress",
    "contentProgress",
    "openProgress",
    "windowVisible",
]:
    if forbidden in dashboard:
        print(f"unexpected legacy motion token {forbidden}", file=sys.stderr)
        sys.exit(1)
PY
grep -q 'NumberAnimation\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should animate offsetScale"
! grep -q 'Behavior on width' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not rely on generic width Behavior animations"
! grep -q 'Behavior on height' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not rely on generic height Behavior animations"
! grep -q 'Behavior on opacity' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not rely on generic opacity Behavior animations"
pass "dashboard motion"

# --- Top bar stays stable during dashboard open -----------------------
! grep -q 'property int cWidth: Popups\.dashboardOpen' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "TopBar center notch should not widen when dashboard opens"
! grep -q 'Popups\.dashboardPageWidth' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "TopBar should not track dashboardPageWidth"
grep -q 'dashboardDrawer\.revealedHeight' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "TopBar height should account for integrated dashboard reveal height"
grep -q 'WlrLayershell\.layer:\s*WlrLayer\.Overlay' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "TopBar should sit above PopupDismiss while dashboard is integrated"
grep -q 'id: notchSurface' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "TopBar should define a fixed notch surface separate from the dashboard drawer"
grep -q 'height:\s*Theme\.notchHeight' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "TopBar notch surface should keep the bar at Theme.notchHeight"
! grep -q 'SeamlessBarShape\s*{[^}]*anchors\.fill:\s*parent' \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  || fail "SeamlessBarShape should not fill the expanded TopBar window"
! grep -q 'Behavior on opacity' \
  config/quickshell/ryoku/vendor/brain-shell/src/modules/Center/CenterContent.qml \
  || fail "CenterContent should not animate opacity during dashboard handoff"
grep -Eq 'visible:\s*!Popups\.dashboardOpen' \
  config/quickshell/ryoku/vendor/brain-shell/src/modules/Center/CenterContent.qml \
  || fail "CenterContent carousel should hide immediately while dashboard is open"
pass "top bar stays stable during dashboard open"

# --- Dashboard surface integration ------------------------------------
! grep -q 'shadowMargin' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Integrated dashboard should not use detached popup shadow margins"
! grep -q 'strokeColor:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Integrated dashboard should not use a detached white outline"
! grep -q 'Qt\.rgba(0,\s*0,\s*0,\s*0\.18' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Integrated dashboard should not render a detached backshadow"
pass "dashboard surface integration"

# --- Dashboard compact footprint -------------------------------------
python3 - <<'PY' || fail "Dashboard footprint should stay compact"
import pathlib
import re
import sys

theme = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/theme/Theme.qml").read_text()
home = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml").read_text()
rail = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml").read_text()

def grab(pattern, text, label):
    m = re.search(pattern, text, re.S)
    if not m:
        print(f"missing {label}", file=sys.stderr)
        sys.exit(1)
    return int(m.group(1))

notch_radius = grab(r'property int notchRadius:\s*([0-9]+)', theme, "Theme.notchRadius")
dashboard_width = grab(r'property int dashboardWidth:\s*([0-9]+)', theme, "Theme.dashboardWidth")
dashboard_height = grab(r'property int dashboardHeight:\s*([0-9]+)', theme, "Theme.dashboardHeight")
col_w = grab(r'readonly property int colW:\s*([0-9]+)', home, "DashHome.colW")
center_w = grab(r'readonly property int centerW:\s*([0-9]+)', home, "DashHome.centerW")
rail_w = grab(r'readonly property int railW:\s*([0-9]+)', home, "DashHome.railW")
gap = grab(r'readonly property int gap:\s*([0-9]+)', home, "DashHome.gap")
profile_h = grab(r'readonly property int profileH:\s*([0-9]+)', home, "DashHome.profileH")
clock_h = grab(r'readonly property int clockH:\s*([0-9]+)', home, "DashHome.clockH")
content_margin = grab(r'readonly property int contentMargin:\s*([0-9]+)', rail, "TelemetryRail.contentMargin")
section_spacing = grab(r'readonly property int sectionSpacing:\s*([0-9]+)', rail, "TelemetryRail.sectionSpacing")

outer_width = dashboard_width + notch_radius * 2
inner_width = col_w + center_w + rail_w + gap * 2

if dashboard_width > 700:
    print(f"dashboardWidth {dashboard_width} exceeds compact cap 700", file=sys.stderr)
    sys.exit(1)
if dashboard_height > 450:
    print(f"dashboardHeight {dashboard_height} exceeds compact cap 450", file=sys.stderr)
    sys.exit(1)
if outer_width > 730:
    print(f"outer dashboard width {outer_width} exceeds compact cap 730", file=sys.stderr)
    sys.exit(1)
if inner_width > dashboard_width - 16:
    print(f"home row width {inner_width} exceeds available inner width {dashboard_width - 16}", file=sys.stderr)
    sys.exit(1)
if col_w > 170 or center_w > 320 or rail_w > 210:
    print(f"home widths too large: col={col_w} center={center_w} rail={rail_w}", file=sys.stderr)
    sys.exit(1)
if gap > 6:
    print(f"home gap {gap} exceeds compact cap 6", file=sys.stderr)
    sys.exit(1)
if profile_h > 145 or clock_h > 195:
    print(f"card heights too large: profile={profile_h} clock={clock_h}", file=sys.stderr)
    sys.exit(1)
if content_margin > 10 or section_spacing > 8:
    print(
        f"telemetry spacing too large: margin={content_margin} spacing={section_spacing}",
        file=sys.stderr,
    )
    sys.exit(1)
PY
pass "dashboard compact footprint"

# --- Dashboard telemetry rail ----------------------------------------
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml ]] \
  || fail "TelemetryRail.qml missing"
grep -q 'TelemetryRail\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml \
  || fail "DashHome should mount TelemetryRail"
! grep -q 'QuickSettings\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml \
  || fail "DashHome QuickSettings column should stay removed"
! grep -q 'Speedometer\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml \
  || fail "Telemetry rail should not reuse Speedometer widgets"
grep -q 'Canvas\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml \
  || fail "Telemetry rail should render a custom graph canvas"
python3 - <<'PY' || fail "Telemetry rail layout budget exceeds dashboard body"
import pathlib
import re
import sys

theme = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/theme/Theme.qml").read_text()
dashboard = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml").read_text()
home = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml").read_text()
rail = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml").read_text()

def grab(pattern, text, label):
    m = re.search(pattern, text, re.S)
    if not m:
        print(f"missing {label}", file=sys.stderr)
        sys.exit(1)
    return int(m.group(1))

dashboard_height = grab(r'property int dashboardHeight:\s*([0-9]+)', theme, "Theme.dashboardHeight")
notch_height = grab(r'property int notchHeight:\s*([0-9]+)', theme, "Theme.notchHeight")
dash_gap = grab(r'readonly property int gap:\s*([0-9]+)', home, "DashHome.gap")
rail_margin = grab(r'readonly property int contentMargin:\s*([0-9]+)', rail, "TelemetryRail.contentMargin")
rail_spacing = grab(r'readonly property int sectionSpacing:\s*([0-9]+)', rail, "TelemetryRail.sectionSpacing")

section_heights = [
    grab(r'readonly property int cpuSectionH:\s*([0-9]+)', rail, "TelemetryRail.cpuSectionH"),
    grab(r'readonly property int memorySectionH:\s*([0-9]+)', rail, "TelemetryRail.memorySectionH"),
    grab(r'readonly property int thermalsSectionH:\s*([0-9]+)', rail, "TelemetryRail.thermalsSectionH"),
    grab(r'readonly property int networkSectionH:\s*([0-9]+)', rail, "TelemetryRail.networkSectionH"),
    grab(r'readonly property int summarySectionH:\s*([0-9]+)', rail, "TelemetryRail.summarySectionH"),
]

if 'topMargin:    Theme.notchHeight + 8' not in dashboard or 'bottomMargin: 8' not in dashboard:
    print("unexpected dashboard body margins", file=sys.stderr)
    sys.exit(1)
if 'height: parent.height' not in home:
    print("expected rail height binding missing", file=sys.stderr)
    sys.exit(1)
if len(re.findall(r'height:\s*root\.(?:cpuSectionH|memorySectionH|thermalsSectionH|networkSectionH|summarySectionH)', rail)) != 5:
    print("expected section heights to be property-backed", file=sys.stderr)
    sys.exit(1)

available_height = dashboard_height - (notch_height + 8) - 8 - dash_gap
declared_budget = rail_margin * 2 + rail_spacing * 4 + sum(section_heights)

if declared_budget > available_height:
    print(f"budget {declared_budget} exceeds available {available_height}", file=sys.stderr)
    sys.exit(1)
PY
pass "dashboard telemetry rail"

# --- Player bars follow shared MPRIS playback -------------------------
grep -q 'readonly property bool isPlaying:' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml \
  || fail "CavaService should expose shared MPRIS playback state"
grep -q 'if (vals\[i\]\.playbackState === MprisPlaybackState\.Playing) return true' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml \
  || fail "CavaService should detect any playing MPRIS source"
grep -q 'CavaService\.isPlaying' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml \
  || fail "PlayerCard bars should use shared CavaService playback state"
! grep -q 'readonly property real _amp: root\.isPlaying \?' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml \
  || fail "PlayerCard bars should not gate on only the selected player's state"
pass "player bars follow shared MPRIS playback"

# --- Active Brain_Shell deps are packaged -----------------------------
grep -qx 'cava' install/ryoku-base.packages \
  || fail "install/ryoku-base.packages should include cava for active player visualizers"
pass "active Brain_Shell deps are packaged"

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
echo "  5. Verify Profile, Calendar, Clock, Player, and the telemetry rail appear together"
echo "  6. Verify the rail shows a CPU graph, RAM bar, thermal lanes, network bars, and compact GPU/disk summaries"
echo "  7. ryoku-theme-set <other-theme> -> colors update across Frame plus TopBar plus Dashboard"
echo "  8. ryoku-toggle-frame -> everything (Frame plus Brain_Shell) disappears"
echo "  9. ryoku-toggle-frame again -> everything comes back"
