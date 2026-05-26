import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Services.System
import qs.noctalia.Services.Theming
import qs.noctalia.Services.UI
import qs.noctalia.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var timeOptions
  property var schemeColorsCache: ({})
  property int cacheVersion: 0
  property var screen

  signal openDownloadPopup

  function extractSchemeName(schemePath) {
    var pathParts = schemePath.split("/");
    var filename = pathParts[pathParts.length - 1];
    var schemeName = filename.replace(".json", "");

    if (schemeName === "Noctalia-default") {
      schemeName = "Noctalia (default)";
    } else if (schemeName === "Noctalia-legacy") {
      schemeName = "Noctalia (legacy)";
    } else if (schemeName === "Tokyo-Night") {
      schemeName = "Tokyo Night";
    } else if (schemeName === "Rosepine") {
      schemeName = "Rose Pine";
    }

    return schemeName;
  }

  function getSchemeColor(schemeName, colorKey) {
    var _ = cacheVersion;

    if (schemeColorsCache[schemeName]) {
      var entry = schemeColorsCache[schemeName];
      var variant = entry;

      if (entry.dark || entry.light) {
        // RYOKU WIRED: use Colours.light to determine dark/light variant
        variant = (!Colours.light) ? (entry.dark || entry.light) : (entry.light || entry.dark);
      }

      if (variant && variant[colorKey]) {
        return variant[colorKey];
      }
    }

    if (colorKey === "mSurface")
      return Color.mSurfaceVariant;
    if (colorKey === "mPrimary")
      return Color.mPrimary;
    if (colorKey === "mSecondary")
      return Color.mSecondary;
    if (colorKey === "mTertiary")
      return Color.mTertiary;
    if (colorKey === "mError")
      return Color.mError;
    return Color.mOnSurfaceVariant;
  }

  function schemeLoaded(schemeName, jsonData) {
    var value = jsonData || {};
    schemeColorsCache[schemeName] = value;
    cacheVersion++;
  }

  Connections {
    target: ColorSchemeService
    function onSchemesChanged() {
      root.schemeColorsCache = {};
      root.cacheVersion++;
    }
  }

  Item {
    id: fileLoaders
    visible: false

    Repeater {
      model: ColorSchemeService.schemes
      delegate: Item {
        FileView {
          path: modelData
          blockLoading: false
          onLoaded: {
            var schemeName = root.extractSchemeName(path);

            try {
              var jsonData = JSON.parse(text());
              root.schemeLoaded(schemeName, jsonData);
            } catch (e) {
              Logger.w("ColorSchemeTab", "Failed to parse JSON for scheme:", schemeName, e);
              root.schemeLoaded(schemeName, null);
            }
          }
        }
      }
    }
  }

  NToggle {
    // RYOKU WIRED: Colours.light (qs.services) reflects dark/light state; Colours.setMode() calls ryoku scheme set -m dark/light
    label: I18n.tr("tooltips.switch-to-dark-mode")
    description: I18n.tr("panels.color-scheme.dark-mode-switch-description")
    checked: !Colours.light
    onToggled: checked => {
                 Colours.setMode(checked ? "dark" : "light");
                 root.cacheVersion++;
               }
  }

  NToggle {
    // TODO: wire to ryoku-theme-set-gnome bin script (no live runtime toggle in ryoku)
    label: I18n.tr("panels.color-scheme.sync-gsettings-label")
    description: I18n.tr("panels.color-scheme.sync-gsettings-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  NComboBox {
    // TODO: wire to ryoku dark mode scheduler (no scheduler in ryoku yet)
    label: I18n.tr("panels.color-scheme.dark-mode-mode-label")
    description: I18n.tr("panels.color-scheme.dark-mode-mode-description")
    enabled: false
    opacity: 0.45

    model: [
      {
        "name": I18n.tr("panels.color-scheme.dark-mode-mode-off"),
        "key": "off"
      },
      {
        "name": I18n.tr("panels.color-scheme.dark-mode-mode-manual"),
        "key": "manual"
      },
      {
        "name": I18n.tr("common.location"),
        "key": "location"
      }
    ]

    currentKey: "off"
  }

  ColumnLayout {
    // TODO: wire to ryoku dark mode scheduler (no scheduler in ryoku yet)
    spacing: Style.marginS
    visible: false
    enabled: false
    opacity: 0.45

    NLabel {
      label: I18n.tr("panels.display.night-light-manual-schedule-label")
      description: I18n.tr("panels.display.night-light-manual-schedule-description")
    }

    RowLayout {
      Layout.fillWidth: false
      spacing: Style.marginS

      NText {
        text: I18n.tr("panels.display.night-light-manual-schedule-sunrise")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      NComboBox {
        model: root.timeOptions
        currentKey: ""
        placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-start")
        minimumWidth: 120
      }

      Item {
        Layout.preferredWidth: 20
      }

      NText {
        text: I18n.tr("panels.display.night-light-manual-schedule-sunset")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      NComboBox {
        model: root.timeOptions
        currentKey: ""
        placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-stop")
        minimumWidth: 120
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    // RYOKU WIRED: GlobalConfig.services.smartScheme (serviceconfig.hpp:31) — enables wallpaper-derived colour scheme
    label: I18n.tr("panels.color-scheme.color-source-use-wallpaper-colors-label")
    description: I18n.tr("panels.color-scheme.color-source-use-wallpaper-colors-description")
    checked: GlobalConfig.services.smartScheme
    onToggled: checked => {
                 GlobalConfig.services.smartScheme = checked;
                 GlobalConfig.save();
               }
  }

  NComboBox {
    // TODO: wire to ryoku per-monitor colour source (no per-monitor config in ryoku yet)
    Layout.fillWidth: true
    label: I18n.tr("panels.color-scheme.wallpaper-monitor-source-label")
    description: I18n.tr("panels.color-scheme.wallpaper-monitor-source-description")
    enabled: false
    opacity: 0.45
    model: []
    currentKey: ""
  }

  NComboBox {
    // TODO: wire to ryoku generation method (no generationMethod config exposed in ryoku yet)
    Layout.fillWidth: true
    label: I18n.tr("panels.color-scheme.wallpaper-method-label")
    description: I18n.tr("panels.color-scheme.wallpaper-method-description")
    enabled: false
    opacity: 0.45
    model: []
    currentKey: ""
  }

  NBox {
    // RYOKU WIRED: visible when GlobalConfig.services.smartScheme is true
    visible: GlobalConfig.services.smartScheme
    Layout.fillWidth: true
    implicitHeight: descriptionColumn.implicitHeight + Style.margin2L
    color: Color.mSurface

    Column {
      id: descriptionColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("panels.color-scheme.color-source-use-wallpaper-colors-description")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }

      Row {
        id: colorPreviewRow
        spacing: Style.marginS

        property int diameter: 16 * Style.uiScaleRatio

        Repeater {
          model: [Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mError]

          Rectangle {
            width: colorPreviewRow.diameter
            height: colorPreviewRow.diameter
            radius: width * 0.5
            color: modelData
          }
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    // RYOKU WIRED: enabled when smartScheme (wallpaper colors) is off
    spacing: Style.marginM
    Layout.fillWidth: true
    enabled: !GlobalConfig.services.smartScheme

    NHeader {
      label: I18n.tr("panels.color-scheme.predefined-title")
      description: I18n.tr("panels.color-scheme.predefined-desc")
      Layout.fillWidth: true
    }

    GridLayout {
      columns: 2
      rowSpacing: Style.marginM
      columnSpacing: Style.marginM
      Layout.fillWidth: true

      Repeater {
        model: ColorSchemeService.schemes

        Rectangle {
          id: schemeItem

          property string schemePath: modelData
          property string schemeName: root.extractSchemeName(modelData)

          opacity: enabled ? 1.0 : 0.6
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          height: 50 * Style.uiScaleRatio
          radius: Style.radiusS
          color: root.getSchemeColor(schemeName, "mSurface")
          border.width: Style.borderL
          border.color: {
            // RYOKU WIRED: compare against Colours.scheme (active ryoku scheme name)
            if ((Colours.scheme === schemeName) && schemeItem.enabled) {
              return Color.mSecondary;
            }
            if (itemMouseArea.containsMouse) {
              return Color.mHover;
            }
            return Color.mOutline;
          }

          RowLayout {
            id: scheme
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginS

            NText {
              text: schemeItem.schemeName
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              Layout.fillWidth: true
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              maximumLineCount: 1
            }

            property int diameter: 16 * Style.uiScaleRatio

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mPrimary")
            }

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mSecondary")
            }

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mTertiary")
            }

            Rectangle {
              width: scheme.diameter
              height: scheme.diameter
              radius: scheme.diameter * 0.5
              color: root.getSchemeColor(schemeItem.schemeName, "mError")
            }
          }

          MouseArea {
            // RYOKU WIRED: disables smartScheme + applies scheme via ryoku-theme-set (Colours.qml)
            id: itemMouseArea
            anchors.fill: parent
            enabled: schemeItem.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              GlobalConfig.services.smartScheme = false;
              GlobalConfig.save();
              Quickshell.execDetached(["ryoku-theme-set", schemeItem.schemeName]);
            }
          }

          Rectangle {
            // RYOKU WIRED: show check when Colours.scheme matches this scheme name
            visible: (Colours.scheme === schemeItem.schemeName) && schemeItem.enabled
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 0
            anchors.topMargin: -3
            width: 20
            height: 20
            radius: Math.min(Style.radiusL, width / 2)
            color: Color.mSecondary
            border.width: Style.borderS
            border.color: Color.mOnSecondary

            NIcon {
              icon: "check"
              pointSize: Style.fontSizeXS
              color: Color.mOnSecondary
              anchors.centerIn: parent
            }
          }

          Behavior on border.color {
            ColorAnimation {
              duration: Style.animationNormal
            }
          }
        }
      }
    }

    NButton {
      text: I18n.tr("panels.color-scheme.download-button")
      icon: "download"
      onClicked: root.openDownloadPopup()
      Layout.alignment: Qt.AlignRight
      Layout.topMargin: Style.marginS
    }
  }
}
