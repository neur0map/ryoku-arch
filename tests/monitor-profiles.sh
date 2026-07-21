#!/usr/bin/env bash
# Fixture test for ryoku-monitor's Ryoku Settings surface: explicit apply, named
# hardware-keyed profiles, and the identity remap that makes a profile survive a
# connector rename. Runs the script in fixture mode (RYOKU_MONITOR_JSON), so no
# live compositor is needed.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
mon="$here/../system/hardware/display/ryoku-monitor"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

conf="$tmp/monitors.lua"
profiles="$tmp/profiles"

# Isolate the implicit applied-layout file from the real ~/.config (autoscale
# reads it and apply writes it). Per-test overrides point elsewhere.
export RYOKU_MONITORS_APPLIED="$tmp/applied-default.json"

# CI runners are VM guests themselves, so pin VM detection off; the DPI
# assertions below must exercise the real buckets. The virtual-display tests
# re-enable it per invocation.
export RYOKU_MONITOR_VM=0

# Two distinct displays, Dell on DP-1 and LG on DP-2.
cat >"$tmp/two.json" <<'JSON'
[
  {"name":"DP-1","make":"Dell","model":"U2720Q","serial":"ABC123","width":3840,"height":2160,"refreshRate":60.0,"x":0,"y":0,"scale":1.5,"transform":0,"vrr":false,"disabled":false,"focused":true,"mirrorOf":"none","availableModes":["3840x2160@60.00Hz","2560x1440@60.00Hz"],"colorManagementPreset":"hdr","sdrBrightness":1.30},
  {"name":"DP-2","make":"LG","model":"27GL850","serial":"XYZ789","width":2560,"height":1440,"refreshRate":144.0,"x":3840,"y":0,"scale":1.0,"transform":0,"vrr":true,"disabled":false,"focused":false,"mirrorOf":"none","availableModes":["2560x1440@144.00Hz"],"colorManagementPreset":"wide"}
]
JSON

# The same two displays, but the connectors have swapped (DP reshuffle).
cat >"$tmp/swapped.json" <<'JSON'
[
  {"name":"DP-2","make":"Dell","model":"U2720Q","serial":"ABC123","width":3840,"height":2160,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,"transform":0,"vrr":false,"disabled":false,"focused":true,"mirrorOf":"none","availableModes":["3840x2160@60.00Hz"]},
  {"name":"DP-1","make":"LG","model":"27GL850","serial":"XYZ789","width":2560,"height":1440,"refreshRate":144.0,"x":0,"y":0,"scale":1.0,"transform":0,"vrr":false,"disabled":false,"focused":false,"mirrorOf":"none","availableModes":["2560x1440@144.00Hz"]}
]
JSON

layout='[
  {"id":"Dell|U2720Q|ABC123","output":"DP-1","mode":"3840x2160@60","position":"0x0","scale":1.5,"transform":0,"vrr":0,"mirror":"none","cm":"hdr","sdrbrightness":1.3,"disabled":false},
  {"id":"LG|27GL850|XYZ789","output":"DP-2","mode":"2560x1440@144","position":"2560x0","scale":1,"transform":1,"vrr":1,"mirror":"none","cm":"wide","disabled":false}
]'

run() { RYOKU_MONITOR_JSON="$tmp/two.json" RYOKU_MONITORS_CONF="$conf" RYOKU_MONITORS_DIR="$profiles" "$mon" "$@"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" || fail "$3"; }

# --- list -----------------------------------------------------------------
n="$(run list | jq 'length')"
[[ $n == 2 ]] || fail "list returned $n monitors, want 2"
run list | jq -e '.[0].id == "Dell|U2720Q|ABC123"' >/dev/null || fail "list missing hardware id"
run list | jq -e '(.[0].modes | length) == 2' >/dev/null || fail "list missing available modes"
run list | jq -e '.[0].cm == "hdr" and .[0].sdrbrightness == 1.3' >/dev/null \
  || fail "list did not map the HDR colour mode and SDR brightness"
run list | jq -e '.[1].cm == "wide"' >/dev/null || fail "list did not map the wide-gamut colour mode"

# --- apply: explicit modes preserved (not highrr) -------------------------
run apply "$layout" >/dev/null
has "$conf" 'mode = "3840x2160@60"' "apply did not keep the chosen 4K mode"
has "$conf" 'mode = "2560x1440@144"' "apply did not keep the chosen LG mode"
has "$conf" 'transform = 1' "apply dropped the transform"
has "$conf" 'vrr = 1' "apply dropped vrr"
has "$conf" 'position = "2560x0"' "apply dropped the position"
has "$conf" 'output = "", mode = "highrr"' "apply omitted the hotplug catch-all"
grep -q 'highrr' <(grep 'DP-1' "$conf") && fail "DP-1 was written as highrr, not its explicit mode"
# Colour management rides the explicit layout: cm is always written with its
# implied bitdepth (srgb->8, wide/hdr->10), and sdrbrightness resets to 1
# outside HDR so turning HDR off in the hub clears the elevated value live.
has "$conf" 'cm = "hdr", bitdepth = 10, sdrbrightness = 1.3' "apply dropped the HDR colour mode / brightness"
has "$conf" 'cm = "wide", bitdepth = 10, sdrbrightness = 1' "apply dropped the wide-gamut mode or left SDR brightness elevated"

# --- save + profiles ------------------------------------------------------
run save desk "$layout" >/dev/null
[[ -f "$profiles/desk.json" ]] || fail "save did not write the profile file"
run profiles | jq -e '.[0].name == "desk" and .[0].matches == true' >/dev/null \
  || fail "profiles did not report desk as matching the connected set"

# A non-matching profile (one display) must not match the two-display set.
echo '{"monitors":[{"id":"Other|Mon|0","output":"DP-9","mode":"highrr","position":"0x0","scale":1}]}' >"$profiles/laptop.json"
run profiles | jq -e '[.[] | select(.name=="laptop")][0].matches == false' >/dev/null \
  || fail "single-display profile wrongly matched the two-display set"

# --- load with a reshuffle: identity remap --------------------------------
RYOKU_MONITOR_JSON="$tmp/swapped.json" RYOKU_MONITORS_CONF="$conf" RYOKU_MONITORS_DIR="$profiles" "$mon" load desk >/dev/null
# Dell's 4K mode must now be written against DP-2 (where Dell now lives), and the
# LG 144Hz mode against DP-1.
grep -q 'output = "DP-2", mode = "3840x2160@60"' "$conf" || fail "load did not remap Dell to its new connector DP-2"
grep -q 'output = "DP-1", mode = "2560x1440@144"' "$conf" || fail "load did not remap LG to its new connector DP-1"

# --- scale snapping on the GUI paths: an invalid scale (stale draft, old or
# hand-edited profile) must never reach Hyprland or disk -- the compositor
# rejects it with the "Invalid scale" overlay on every login and substitutes
# its own. 1.5 is invalid for 1280x720 (1280/1.5 = 853.33); nearest valid: 1.6.
cat >"$tmp/tv.json" <<'JSON'
[{"name":"HDMI-A-1","make":"Acme","model":"TV720","serial":"T1","width":1280,"height":720,
  "physicalWidth":700,"physicalHeight":390,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,
  "transform":0,"vrr":false,"disabled":false,"focused":true,"mirrorOf":"none",
  "availableModes":["1280x720@60.00Hz","1366x768@60.00Hz"]}]
JSON
tvlayout='[{"id":"Acme|TV720|T1","output":"HDMI-A-1","mode":"1280x720@60","position":"0x0","scale":1.5,"transform":0,"vrr":0,"mirror":"none","disabled":false}]'
runT() { RYOKU_MONITOR_JSON="$tmp/tv.json" RYOKU_MONITORS_CONF="$conf" \
  RYOKU_MONITORS_DIR="$profiles" RYOKU_MONITORS_APPLIED="$tmp/tv-applied.json" "$mon" "$@"; }
runT apply "$tvlayout" >/dev/null
has "$conf" 'scale = 1.6' "apply did not snap the invalid 720p scale 1.5 to 1.6"
grep -qF 'scale = 1.5' "$conf" && fail "apply persisted the invalid scale 1.5"
# A layout with no colour mode is plain sRGB at 8-bit with SDR brightness reset,
# so switching a display back from HDR fully clears the 10-bit / bright state.
has "$conf" 'cm = "srgb", bitdepth = 8, sdrbrightness = 1' "apply did not write the sRGB reset (8-bit, SDR brightness 1)"
jq -e '.monitors[0].scale == 1.6' "$tmp/tv-applied.json" >/dev/null \
  || fail "the applied layout recorded the invalid scale instead of the snapped one"
runT save tv "$tvlayout" >/dev/null
jq -e '.monitors[0].scale == 1.6' "$profiles/tv.json" >/dev/null \
  || fail "save persisted the invalid scale into the profile"

# --- list: the per-resolution ladders the hub's scale stepper walks. Only
# Hyprland-valid scales (1/120 multiples dividing both dims to whole pixels),
# and never below a 640x360 logical desktop: 720p tops out at 2x, and the odd
# 1366x768 panel has exactly four steps.
runT list | jq -e '.[0].scaleLadders["1280x720"] == [0.5,0.5333,0.625,0.6667,0.8,0.8333,1,1.0667,1.25,1.3333,1.6,1.6667,2]' >/dev/null \
  || fail "wrong 1280x720 scale ladder: $(runT list | jq -c '.[0].scaleLadders["1280x720"]')"
runT list | jq -e '.[0].scaleLadders["1366x768"] == [0.5,0.6667,1,2]' >/dev/null \
  || fail "wrong 1366x768 scale ladder: $(runT list | jq -c '.[0].scaleLadders["1366x768"]')"

# --- autoscale DPI snapping: the wanted scale must be Hyprland-valid for the
# panel (a 1/120 multiple dividing both dims to whole pixels), never the raw DPI
# bucket, which Hyprland rejects with an "Invalid scale" error on many panels.
cat >"$tmp/dpi.json" <<'JSON'
[
  {"name":"eDP-1","width":2560,"height":1600,"refreshRate":165.0,"x":0,"y":0,"scale":1.0,"physicalWidth":300,"physicalHeight":190,"disabled":false},
  {"name":"DP-3","width":3840,"height":2160,"refreshRate":144.0,"x":0,"y":0,"scale":1.0,"physicalWidth":600,"physicalHeight":340,"disabled":false},
  {"name":"DP-4","width":1920,"height":1080,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,"physicalWidth":530,"physicalHeight":300,"disabled":false}
]
JSON
specout="$(RYOKU_MONITOR_JSON="$tmp/dpi.json" bash -c 'source "$1"; monitors_json | dpi_specs' _ "$mon")"
field4() { awk -F'|' -v n="$1" '$1==n {print $4}' <<<"$specout"; }
# 2560x1600 at ~216dpi buckets to 1.5, invalid (2560/1.5=1706.67); snap to 1.6.
[[ "$(field4 eDP-1)" == "1.6" ]] || fail "high-DPI 2560 panel must snap to valid 1.6, got $(field4 eDP-1)"
# 4K at ~163dpi buckets to 1.5, which IS valid (3840/1.5=2560), so it is kept.
[[ "$(field4 DP-3)" == "1.5" ]] || fail "valid 4K 1.5 must be kept, got $(field4 DP-3)"
# Low-DPI 1080p stays 1x.
[[ "$(field4 DP-4)" == "1" ]] || fail "low-DPI 1080p must stay 1x, got $(field4 DP-4)"

# --- virtual displays: a hypervisor's EDID is fiction, autoscale must stay 1x.
# Connector name alone forces it, even with a plausible fake physical size that
# would otherwise bucket well above 1x.
cat >"$tmp/vm.json" <<'JSON'
[
  {"name":"Virtual-1","width":2560,"height":1600,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,"physicalWidth":300,"physicalHeight":190,"disabled":false}
]
JSON
vmout="$(RYOKU_MONITOR_JSON="$tmp/vm.json" bash -c 'source "$1"; monitors_json | dpi_specs' _ "$mon")"
[[ "$(awk -F'|' '$1=="Virtual-1" {print $4}' <<<"$vmout")" == "1" ]] \
  || fail "Virtual-* connector must autoscale to 1x, got: $vmout"
# A detected VM guest forces 1x on every output, whatever the connector says.
vmout="$(RYOKU_MONITOR_JSON="$tmp/dpi.json" RYOKU_MONITOR_VM=1 bash -c 'source "$1"; monitors_json | dpi_specs' _ "$mon")"
[[ "$(awk -F'|' '$1=="eDP-1" {print $4}' <<<"$vmout")" == "1" ]] \
  || fail "VM guest must autoscale the eDP panel to 1x, got: $vmout"

# --- manual override: autoscale leaves a pinned output out of the generated conf
# (the user manages it in monitors.user.lua) and still writes the others.
userlua="$tmp/monitors.user.lua"
echo 'hl.monitor({ output = "DP-1", mode = "highrr", position = "0x0", scale = 1 })' >"$userlua"
RYOKU_MONITOR_JSON="$tmp/two.json" RYOKU_MONITORS_CONF="$conf" RYOKU_MONITORS_DIR="$tmp/none" \
  RYOKU_MONITORS_APPLIED="$tmp/none-applied.json" RYOKU_MONITORS_USER="$userlua" "$mon" autoscale >/dev/null
grep -qF 'output = "DP-1"' "$conf" && fail "autoscale wrote a rule for pinned DP-1 (should defer to monitors.user.lua)"
has "$conf" 'output = "DP-2"' "autoscale dropped the non-pinned DP-2"

# --- applied layout: Apply persists across login (the scale-reset fix) --------
# One HiDPI panel whose live scale (2.5) differs from both an applied 1.0 and its
# DPI bucket, so each code path is distinguishable in fixture mode.
cat >"$tmp/one.json" <<'JSON'
[{"name":"eDP-1","make":"Acme","model":"Panel","serial":"S1","width":2560,"height":1600,
  "refreshRate":60.0,"physicalWidth":300,"physicalHeight":188,"x":0,"y":0,"scale":2.5,
  "transform":0,"vrr":false,"disabled":false,"focused":true,
  "availableModes":["2560x1600@60.000Hz"]}]
JSON
appliedfile="$tmp/applied.json"
layout1='[{"id":"Acme|Panel|S1","output":"eDP-1","mode":"2560x1600@60","position":"0x0","scale":1.0,"transform":0,"vrr":0,"mirror":"none","disabled":false}]'
runA() { RYOKU_MONITOR_JSON="$tmp/one.json" RYOKU_MONITORS_CONF="$conf" \
  RYOKU_MONITORS_DIR="$tmp/none" RYOKU_MONITORS_APPLIED="$appliedfile" "$mon" "$@"; }
eDP() { grep 'output = "eDP-1"' "$conf"; }

# Apply records the applied layout...
runA apply "$layout1" >/dev/null
[[ -f "$appliedfile" ]] || fail "apply did not record the applied layout"
jq -e '.monitors[0].scale == 1' "$appliedfile" >/dev/null || fail "applied layout lost the scale"

# ...and a plain login autoscale recalls it (scale 1.0), not the live/DPI scale (2.5).
runA autoscale >/dev/null
eDP | grep -qE 'scale = 1(\.0)?[, ]' || fail "autoscale did not recall the applied scale (got: $(eDP))"
eDP | grep -q 'scale = 2.5' && fail "autoscale used the live scale, not the applied layout"

# A forced DPI pass clears the override so it stops winning at login.
runA autoscale --no-profile >/dev/null
[[ -f "$appliedfile" ]] && fail "autoscale --no-profile did not clear the applied layout"

# An applied layout for a different display set is ignored (DPI/live wins).
runA apply "$layout1" >/dev/null
echo '{"monitors":[{"id":"Other|Mon|0","output":"DP-9","mode":"highrr","position":"0x0","scale":1.0}]}' >"$appliedfile"
runA autoscale >/dev/null
eDP | grep -q 'scale = 2.5' || fail "autoscale recalled a non-matching applied layout"

# --- settle: recover a display a degraded link left below its resolution -------
# settle re-asserts each output's intended mode from monitors.lua; --check reports
# drift (exit 1) and changes nothing -- the read-only signal `ryoku doctor` uses.
settle_conf="$tmp/settle.lua"
: >"$tmp/none.lua"
sc() { printf '%s\n' "$1" >"$settle_conf"; }   # set the monitors.lua intent
chk() {  # chk FIXTURE USERLUA EXPECT(drift|ok) MSG
  local rc=0
  RYOKU_MONITOR_JSON="$1" RYOKU_MONITORS_CONF="$settle_conf" RYOKU_MONITORS_USER="$2" \
    "$mon" settle --check || rc=$?
  if [[ "$3" == drift ]]; then (( rc != 0 )) || fail "$4"; else (( rc == 0 )) || fail "$4"; fi
}
cat >"$tmp/stuck.json" <<'JSON'
[{"name":"DP-1","make":"V","model":"M","serial":"1","width":800,"height":600,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,"transform":0,"vrr":false,"disabled":false,"focused":true,"mirrorOf":"none","availableModes":["1920x1080@60.00Hz","800x600@60.00Hz"]}]
JSON
cat >"$tmp/topped.json" <<'JSON'
[{"name":"DP-1","make":"V","model":"M","serial":"1","width":1920,"height":1080,"refreshRate":60.0,"x":0,"y":0,"scale":1.0,"transform":0,"vrr":false,"disabled":false,"focused":true,"mirrorOf":"none","availableModes":["1920x1080@60.00Hz","800x600@60.00Hz"]}]
JSON
# A highrr output stuck below its max resolution is drift; at its max it is not.
sc 'hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })'
chk "$tmp/stuck.json"  "$tmp/none.lua" drift "settle missed a highrr display stuck below its max resolution"
chk "$tmp/topped.json" "$tmp/none.lua" ok    "settle reported drift for a display already at its max"
# A deliberate explicit pick (config says 800x600) is respected, not bumped to 1080p.
sc 'hl.monitor({ output = "DP-1", mode = "800x600@60", position = "0x0", scale = 1 })'
chk "$tmp/stuck.json"  "$tmp/none.lua" ok    "settle overrode a deliberate explicit 800x600 pick"
# But an explicit 1080p pick the link dropped to 800x600 is drift (restore it).
sc 'hl.monitor({ output = "DP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })'
chk "$tmp/stuck.json"  "$tmp/none.lua" drift "settle missed an explicit 1080p pick degraded to 800x600"
# A monitors_user.lua-pinned output is left to the user, never re-asserted.
sc 'hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })'
printf '%s\n' 'hl.monitor({ output = "DP-1", mode = "800x600@60" })' >"$tmp/pin.lua"
chk "$tmp/stuck.json"  "$tmp/pin.lua"  ok    "settle touched a monitors_user.lua-pinned output"

echo "monitor-profiles: all checks passed"
