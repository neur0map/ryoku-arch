pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.services
import qs.settingsgui.Services.Platform

// The plugins menu (leader: Super+X). A focused overlay listing every installed frame
// plugin and its key; pressing a key toggles that plugin's popout and closes the menu.
// Keys are pure shell state (manifest frame.key + the user's per-plugin override), so this
// needs no Hyprland binds beyond the single leader that opens it.
Scope {
  id: scope

  function buildEntries(): var {
    const out = [];
    const loaded = PluginService.loadedPlugins;
    for (const id in loaded) {
      const p = loaded[id];
      const ep = p && p.manifest && p.manifest.entryPoints;
      if (!(ep && ep.framePanel))
        continue;
      const frame = (p.manifest && p.manifest.frame) || ({});
      const override = PluginRegistry.getPluginKeybind(id);
      out.push({
        id: id,
        name: frame.label || p.manifest.name || id,
        icon: frame.icon || "extension",
        key: ((override && override.length > 0) ? override : (frame.key || "")).toLowerCase()
      });
    }
    out.sort((a, b) => a.name.localeCompare(b.name));
    return out;
  }

  function activate(key: string): void {
    const entries = buildEntries();
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].key.length > 0 && entries[i].key === key) {
        loader.active = false;
        Visibilities.framePluginsForActive()?.toggle(entries[i].id);
        return;
      }
    }
  }

  LazyLoader {
    id: loader

    Variants {
      model: Screens.screens

      StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "plugin-menu"
        color: "transparent"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Item {
          id: keyScope

          anchors.fill: parent
          focus: true

          Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
              loader.active = false;
              event.accepted = true;
              return;
            }
            if (event.text && event.text.length === 1) {
              scope.activate(event.text.toLowerCase());
              event.accepted = true;
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: loader.active = false
          }

          StyledRect {
            anchors.centerIn: parent
            implicitWidth: Math.min(420, win.screen.width - 80)
            implicitHeight: card.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surface
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outline, 0.28)

            MouseArea {
              anchors.fill: parent
            }

            ColumnLayout {
              id: card

              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Tokens.padding.large
              spacing: Tokens.spacing.normal

              RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.normal

                MaterialIcon {
                  text: "extension"
                  color: Colours.palette.m3primary
                  font.pointSize: Tokens.font.size.large
                }

                StyledText {
                  Layout.fillWidth: true
                  text: qsTr("Plugins")
                  font.pointSize: Tokens.font.size.normal
                }

                StyledText {
                  text: qsTr("press a key")
                  color: Colours.palette.m3onSurfaceVariant
                  font.pointSize: Tokens.font.size.small
                }
              }

              StyledText {
                Layout.fillWidth: true
                visible: pluginRepeater.count === 0
                text: qsTr("No plugins installed. Add some in Settings > Plugins.")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                wrapMode: Text.WordWrap
              }

              Repeater {
                id: pluginRepeater

                model: scope.buildEntries()

                delegate: RowLayout {
                  id: row

                  required property var modelData

                  Layout.fillWidth: true
                  spacing: Tokens.spacing.normal

                  StyledRect {
                    implicitWidth: 30
                    implicitHeight: 26
                    radius: Tokens.rounding.small
                    color: row.modelData.key.length > 0 ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outline, 0.24)

                    StyledText {
                      anchors.centerIn: parent
                      text: row.modelData.key.length > 0 ? row.modelData.key.toUpperCase() : "-"
                      color: row.modelData.key.length > 0 ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                      font.pointSize: Tokens.font.size.small
                    }
                  }

                  MaterialIcon {
                    text: row.modelData.icon
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.normal
                  }

                  StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  IpcHandler {
    function open(): void {
      loader.activeAsync = true;
    }

    function close(): void {
      loader.active = false;
    }

    function toggle(): void {
      loader.activeAsync = !loader.active;
    }

    target: "plugins"
  }
}
