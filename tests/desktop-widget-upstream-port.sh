#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  local path=$1
  [[ -f $ROOT_DIR/$path ]] || fail "missing $path"
}

require_rg() {
  local pattern=$1
  local path=$2
  rg -q -- "$pattern" "$ROOT_DIR/$path" || fail "missing pattern in $path: $pattern"
}

reject_rg() {
  local pattern=$1
  local path=$2
  if rg -q -- "$pattern" "$ROOT_DIR/$path"; then
    rg -n -- "$pattern" "$ROOT_DIR/$path" >&2
    fail "unexpected pattern in $path: $pattern"
  fi
}

require_json_key() {
  local path=$1
  local expression=$2

  jq -e "$expression" "$ROOT_DIR/$path" >/dev/null || fail "missing json expression in $path: $expression"
}

require_file shell/modules/background/widgets/WidgetSurface.qml
require_file shell/modules/background/widgets/notes/NotesWidget.qml
require_file shell/modules/background/widgets/notes/qmldir
require_file shell/modules/background/widgets/calendar/CalendarUpcomingWidget.qml
require_file shell/modules/background/widgets/calendar/qmldir

require_rg 'Appearance\.ryokuEverywhere' shell/modules/background/widgets/WidgetSurface.qml
require_rg 'Appearance\.ryoku\.colBorder' shell/modules/background/widgets/WidgetSurface.qml
require_rg 'Wallpapers\.effectiveWallpaperUrl' shell/modules/background/widgets/WidgetSurface.qml
require_rg 'surfaceUseBlur: root\.useBlur' shell/modules/background/widgets/notes/NotesWidget.qml
require_rg 'surfaceUseBlur: root\.useBlur' shell/modules/background/widgets/calendar/CalendarUpcomingWidget.qml
require_rg 'readonly property bool useBlur: root\._readConfigKey\("useBlur"\) \?\? false' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg 'enabled: root\.draggable' shell/modules/common/widgets/widgetCanvas/AbstractWidget.qml
require_rg 'draggable: GlobalStates\.widgetEditMode && !GlobalStates\.screenLocked && !root\.locked' shell/modules/background/widgets/notes/NotesWidget.qml

for widget_file in \
  shell/modules/background/widgets/clock/ClockWidget.qml \
  shell/modules/background/widgets/visualizer/VisualizerWidget.qml \
  shell/modules/background/widgets/systemMonitor/SystemMonitorWidget.qml \
  shell/modules/background/widgets/battery/BatteryWidget.qml; do
  require_rg 'WidgetSurface \{' "$widget_file"
  require_rg 'surfaceUseBlur: root\.useBlur' "$widget_file"
done

require_rg 'import qs\.modules\.background\.widgets\.notes' shell/modules/background/Background.qml
require_rg 'import qs\.modules\.background\.widgets\.calendar' shell/modules/background/Background.qml
require_rg 'key: "notes"' shell/modules/background/Background.qml
require_rg 'key: "calendarUpcoming"' shell/modules/background/Background.qml
require_rg 'sourceComponent: NotesWidget' shell/modules/background/Background.qml
require_rg 'sourceComponent: CalendarUpcomingWidget' shell/modules/background/Background.qml

require_rg 'WidgetCard \{ widgetKey: "notes"' shell/modules/background/widgets/WidgetManagerPanel.qml
require_rg 'WidgetCard \{ widgetKey: "calendarUpcoming"' shell/modules/background/widgets/WidgetManagerPanel.qml
require_rg 'readonly property bool _supportsAppearance: !isCustom' shell/modules/background/widgets/WidgetManagerPanel.qml
require_rg '"clock", "visualizer", "systemMonitor", "battery", "notes", "calendarUpcoming"' shell/modules/background/widgets/WidgetManagerPanel.qml
require_rg 'Config\.getNestedValue\(card\._cfgPrefix \+ "\.useBlur", false\)' shell/modules/background/widgets/WidgetManagerPanel.qml
reject_rg 'Config\.getNestedValue\(card\._cfgPrefix \+ "\.useBlur", true\)' shell/modules/background/widgets/WidgetManagerPanel.qml

require_rg 'property JsonObject notes: JsonObject' shell/modules/common/Config.qml
require_rg 'property JsonObject calendarUpcoming: JsonObject' shell/modules/common/Config.qml
require_rg 'property string text: ""' shell/modules/common/Config.qml
require_rg 'property int maxEvents: 5' shell/modules/common/Config.qml

require_json_key shell/defaults/config.json '.background.widgets.notes'
require_json_key shell/defaults/config.json '.background.widgets.calendarUpcoming'
require_json_key shell/defaults/config.json '.background.widgets.notes.placementStrategy == "leastBusy"'
require_json_key shell/defaults/config.json '.background.widgets.calendarUpcoming.placementStrategy == "leastBusy"'
require_json_key shell/defaults/config.json '.background.widgets.notes.useBlur == false'
require_json_key shell/defaults/config.json '.background.widgets.calendarUpcoming.useBlur == false'

require_rg 'TextEdit \{' shell/modules/background/widgets/notes/NotesWidget.qml
require_rg 'onTextChanged: _saveDebounce\.restart\(\)' shell/modules/background/widgets/notes/NotesWidget.qml
require_rg 'placementStrategy: "leastBusy"' shell/modules/background/widgets/notes/NotesWidget.qml
require_rg 'placementStrategy: "leastBusy"' shell/modules/background/widgets/calendar/CalendarUpcomingWidget.qml
require_rg 'property string placementStrategy: "leastBusy"' shell/modules/common/Config.qml
least_busy_state_count=$(rg -c 'defaultStrategy: "leastBusy"' shell/modules/settings/DesktopWidgetsConfig.qml)
(( least_busy_state_count >= 5 )) || fail "expected new widgets to default to leastBusy placement"
require_rg 'Events\.getUpcomingEvents\(30\)' shell/modules/background/widgets/calendar/CalendarUpcomingWidget.qml
require_rg 'CalendarSync\.getEventsForDate\(d\)' shell/modules/background/widgets/calendar/CalendarUpcomingWidget.qml

echo "desktop widget upstream port ok"
