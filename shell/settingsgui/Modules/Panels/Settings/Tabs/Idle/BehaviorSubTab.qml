import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Don't write the compiled defaults back as overrides while bindings settle.
  property bool ready: false
  Component.onCompleted: ready = true

  // Idle behaviour is driven by GlobalConfig.general.idle.timeouts (IdleMonitors.qml).
  // Each entry is { timeout, idleAction, returnAction, enabled }. We surface the four
  // known actions as fixed rows and edit their entry in place.

  // Identify a timeout entry. Prefer the scalar "kind" tag (reliable across the C++
  // round-trip); fall back to stringifying idleAction for legacy entries that predate it.
  function entryKind(entry) {
    if (entry && entry.kind)
      return entry.kind;
    var action = entry ? entry.idleAction : undefined;
    if (action === "lock")
      return "lock";
    if (action === "dpms off")
      return "dpms";
    var joined = (action === undefined || action === null) ? "" : String(action);
    if (joined.indexOf("ryoku-launch-screensaver") !== -1)
      return "screensaver";
    if (joined.indexOf("suspend") !== -1)
      return "suspend";
    return "custom";
  }

  function defaultEntry(kind) {
    if (kind === "screensaver")
      return {
        "kind": "screensaver",
        "timeout": 300,
        "idleAction": ["ryoku-launch-screensaver"],
        "returnAction": ["pkill", "-f", "org.ryoku.screensaver"]
      };
    if (kind === "lock")
      return {
        "kind": "lock",
        "timeout": 600,
        "idleAction": "lock"
      };
    if (kind === "dpms")
      return {
        "kind": "dpms",
        "timeout": 900,
        "idleAction": "dpms off",
        "returnAction": "dpms on"
      };
    if (kind === "suspend")
      return {
        "kind": "suspend",
        "timeout": 1800,
        "idleAction": ["systemctl", "suspend-then-hibernate"]
      };
    return null;
  }

  function entryIndex(kind) {
    var list = GlobalConfig.general.idle.timeouts;
    for (var i = 0; i < list.length; i++) {
      if (entryKind(list[i]) === kind)
        return i;
    }
    return -1;
  }

  function rowTimeout(kind) {
    var i = entryIndex(kind);
    return i >= 0 ? GlobalConfig.general.idle.timeouts[i].timeout : defaultEntry(kind).timeout;
  }

  function rowEnabled(kind) {
    var i = entryIndex(kind);
    return i >= 0 && (GlobalConfig.general.idle.timeouts[i].enabled !== false);
  }

  function setRow(kind, props) {
    var list = GlobalConfig.general.idle.timeouts.slice();
    var i = entryIndex(kind);
    if (i >= 0) {
      list[i] = Object.assign({}, list[i], props);
    } else {
      list.push(Object.assign({}, defaultEntry(kind), props));
    }
    GlobalConfig.general.idle.timeouts = list;
    GlobalConfig.save();
  }

  RowLayout {
    Layout.fillWidth: true
    visible: IdleService.nativeIdleMonitorAvailable

    NLabel {
      label: I18n.tr("panels.idle.status-label")
      description: I18n.tr("panels.idle.status-description")
    }

    Item {
      Layout.fillWidth: true
    }

    NText {
      Layout.alignment: Qt.AlignBottom | Qt.AlignRight
      text: IdleService.idleSeconds > 0 ? I18n.trp("common.second", IdleService.idleSeconds) : I18n.tr("common.active")
      family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeM
      color: IdleService.idleSeconds > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
    }
  }

  NLabel {
    visible: !IdleService.nativeIdleMonitorAvailable
    description: I18n.tr("panels.idle.unavailable")
  }

  NDivider {
    Layout.fillWidth: true
  }

  ActionRow {
    actionName: "Screensaver"
    actionDescription: "Show the ryoku ASCII screensaver after this delay."
    kind: "screensaver"
  }

  // Terminal that runs the screensaver
  NComboBox {
    Layout.fillWidth: true
    Layout.leftMargin: Style.marginL
    label: "Screensaver terminal"
    description: "Terminal that hosts the ASCII screensaver. Kitty is the ryoku default."
    enabled: root.rowEnabled("screensaver")
    model: [
      {
        "key": "kitty",
        "name": "Kitty (default)"
      },
      {
        "key": "alacritty",
        "name": "Alacritty"
      },
      {
        "key": "ghostty",
        "name": "Ghostty"
      }
    ]
    currentKey: GlobalConfig.general.idle.screensaverTerminal || "kitty"
    onSelected: key => {
      GlobalConfig.general.idle.screensaverTerminal = key;
      GlobalConfig.save();
    }
  }

  ActionRow {
    actionName: "Lock screen"
    actionDescription: "Lock the session after this delay."
    kind: "lock"
  }

  ActionRow {
    actionName: "Turn off screen"
    actionDescription: "Power the display off (DPMS) after this delay."
    kind: "dpms"
  }

  ActionRow {
    actionName: I18n.tr("common.suspend")
    actionDescription: "Suspend (then hibernate) after this delay."
    kind: "suspend"
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: "Pause while audio plays"
    description: "Don't trigger idle actions while audio is playing."
    checked: GlobalConfig.general.idle.inhibitWhenAudio
    onToggled: checked => {
      GlobalConfig.general.idle.inhibitWhenAudio = checked;
      GlobalConfig.save();
    }
  }

  component ActionRow: RowLayout {
    id: rowRoot
    Layout.fillWidth: true
    spacing: Style.marginM

    property string actionName
    property string actionDescription
    property string kind

    NToggle {
      Layout.alignment: Qt.AlignVCenter
      checked: root.rowEnabled(rowRoot.kind)
      onToggled: checked => root.setRow(rowRoot.kind, {
                                          "enabled": checked
                                        })
    }

    NSpinBox {
      Layout.fillWidth: true
      enabled: root.rowEnabled(rowRoot.kind)
      label: rowRoot.actionName
      description: rowRoot.actionDescription
      from: 5
      to: 86400
      stepSize: 30
      suffix: "s"
      value: root.rowTimeout(rowRoot.kind)
      onValueChanged: {
        if (root.ready && value !== root.rowTimeout(rowRoot.kind))
          root.setRow(rowRoot.kind, {
                        "timeout": value
                      });
      }
    }
  }
}
