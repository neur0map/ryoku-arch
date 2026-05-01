#!/bin/bash
# Static regression checks for the narrow dashboard telemetry rail.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

rail="config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml"
home="config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml"

[[ -f $rail ]] || fail "TelemetryRail.qml missing"
[[ -f $home ]] || fail "DashHome.qml missing"

python3 - <<'PY' || fail "telemetry rail lost narrow single-surface layout"
import pathlib
import re
import sys

rail = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml").read_text()
home = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml").read_text()

def require(pattern, message, body=rail):
  if not re.search(pattern, body, re.S):
    print(message, file=sys.stderr)
    sys.exit(1)

def reject(pattern, message, body=rail):
  if re.search(pattern, body, re.S):
    print(message, file=sys.stderr)
    sys.exit(1)

require(r"readonly property int railW:\s*190", "telemetry rail width should stay narrow", home)

for component in ("RailDivider", "SectionHeader", "MetricLine", "InfoLine"):
  require(rf"component\s+{component}\s*:", f"{component} helper component missing")

require(r"id:\s*advancedButton.*?Item\s*\{", "Advanced should be a plain text control, not a filled chip")
reject(r"Rectangle\s*\{\s*id:\s*advancedButton", "Advanced control should not be a nested card/chip")
reject(r"StatCard\s*\{", "telemetry rail should not use nested cards")

require(r"id:\s*powerToggle.*?anchors\.bottom:\s*parent\.bottom", "power toggle should sit on a compact bottom row")
reject(r"id:\s*powerToggle.*?anchors\.left:\s*cpuPct\.right", "power toggle should not crowd the CPU percentage")
reject(r"id:\s*powerSaverLabel", "old wide power-saver label should not return")

require(r"id:\s*cpuPct.*?font\.pixelSize:\s*27", "CPU percentage should be reduced from the old oversized treatment")
reject(r"font\.letterSpacing:\s*-", "telemetry typography should not use negative tracking")

for title in ("Memory", "Thermals", "Network", "System"):
  require(rf"SectionHeader\s*\{{.*?title:\s*\"{title}\"", f"{title} should use the shared section header")

for label in ("RAM", "CPU", "GPU", "UP", "DOWN"):
  require(rf"MetricLine\s*\{{.*?label:\s*\"{label}\"", f"{label} should use aligned metric rows")

require(r"InfoLine\s*\{.*?label:\s*\"Display\"", "display summary should be a plain footer row")
reject(r"Rectangle\s*\{[^{}]*radius:\s*6[^{}]*color:\s*Qt\.rgba\(1,\s*1,\s*1,\s*0\.035\)",
       "display summary should not use the old internal rounded chip")

divider_count = len(re.findall(r"RailDivider\s*\{", rail))
if divider_count < 4:
  print("section rhythm should be set by dividers, not nested boxes", file=sys.stderr)
  sys.exit(1)
PY

if command -v qmllint >/dev/null; then
  qmllint "$rail" >/dev/null || fail "TelemetryRail.qml qmllint failed"
fi

pass "telemetry rail keeps narrow single-surface layout"
