import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU: Credits & Licenses subtab. Ryoku is built on the work of these
// projects; each is grouped by its license obligation. Logos in Assets/credits/.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginM
  }

  NHeader {
    Layout.alignment: Qt.AlignHCenter
    label: "Credits & Licenses"
    description: "Ryoku is built on the work of these projects."
  }

  // --- Credit groups, ordered by license obligation ---
  Repeater {
    model: [
      {
        "title": "Bundled in source — AGPL-3.0",
        "note": "Distributed within Ryoku; AGPL-3.0 copyleft and Section 13 obligations apply.",
        "items": [
          {
            "name": "Ambxst",
            "license": "AGPL-3.0",
            "desc": "Axenide/Ambxst — basis for Ryoku's dynamic island, dashboard and notifications.",
            "icon": "ambxst.svg",
            "url": "https://github.com/Axenide/Ambxst"
          }
        ]
      },
      {
        "title": "Bundled in source — MIT",
        "note": "Distributed within Ryoku under the MIT License; proper credit given to the original author.",
        "items": [
          {
            "name": "Noctalia Shell",
            "license": "MIT",
            "desc": "noctalia-dev/noctalia-shell — basis for Ryoku's settings UI. © 2025 noctalia-dev.",
            "icon": "noctalia.svg",
            "url": "https://github.com/noctalia-dev/noctalia-shell"
          }
        ]
      },
      {
        "title": "Bundled (optional) — GPL-3.0",
        "note": "Optional component installable on demand.",
        "items": [
          {
            "name": "qylock",
            "license": "GPL-3.0",
            "desc": "Darkkal44 — optional SDDM greeter and lock screen theme integration.",
            "icon": "qylock.png",
            "url": "https://github.com/Darkkal44/qylock"
          }
        ]
      },
      {
        "title": "Design & code inspiration",
        "note": "Projects that inspired or contributed ideas to Ryoku.",
        "items": [
          {
            "name": "Caelestia",
            "license": "GPL-3.0",
            "desc": "caelestia-dots/shell — Hyprland / Quickshell shell; design and widget inspiration.",
            "icon": "caelestia.svg",
            "url": "https://github.com/caelestia-dots/shell"
          },
          {
            "name": "illogical-impulse (end-4)",
            "license": "GPL-3.0",
            "desc": "end-4/dots-hyprland — usability-first Hyprland shell; design inspiration.",
            "icon": "illogical-impulse.png",
            "url": "https://github.com/end-4/dots-hyprland"
          },
          {
            "name": "iNiR",
            "license": "GPL-3.0",
            "desc": "snowarch/iNiR — Quickshell shell for the Niri compositor; inspiration.",
            "icon": "inir.png",
            "url": "https://github.com/snowarch/iNiR"
          },
          {
            "name": "Omarchy",
            "license": "MIT",
            "desc": "basecamp/omarchy — opinionated Arch / Hyprland system; base and workflow inspiration.",
            "icon": "omarchy.svg",
            "url": "https://github.com/basecamp/omarchy"
          },
          {
            "name": "ActivSpot",
            "license": "",
            "desc": "Devvvmn/ActivSpot — Dynamic Island code and interaction inspiration.",
            "icon": "",
            "url": "https://github.com/Devvvmn/ActivSpot"
          },
          {
            "name": "HyprMod",
            "license": "",
            "desc": "BlueManCZ/hyprmod — Hyprland GUI configuration integration inspiration.",
            "icon": "",
            "url": "https://github.com/BlueManCZ/hyprmod"
          },
          {
            "name": "skwd-wall",
            "license": "MIT",
            "desc": "liixini/skwd-wall — aesthetics-first Quickshell wallpaper selector.",
            "icon": "skwd-wall.svg",
            "url": "https://github.com/liixini/skwd-wall"
          }
        ]
      }
    ]

    delegate: ColumnLayout {
      id: creditGroup

      required property var modelData

      Layout.fillWidth: true
      spacing: Style.marginS

      NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginXS
      }

      NHeader {
        label: creditGroup.modelData.title
        description: creditGroup.modelData.note
      }

      Repeater {
        model: creditGroup.modelData.items

        delegate: Rectangle {
          id: creditCard

          required property var modelData

          Layout.fillWidth: true
          Layout.preferredHeight: cardRow.implicitHeight + Style.marginM * 2
          radius: Style.iRadiusS
          color: cardMouse.containsMouse ? Color.mHover : Color.mSurfaceVariant

          Behavior on color {
            ColorAnimation {
              duration: Style.animationFast
              easing.type: Easing.InOutQuad
            }
          }

          RowLayout {
            id: cardRow
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Image {
              visible: creditCard.modelData.icon !== ""
              Layout.preferredWidth: visible ? 40 : 0
              Layout.preferredHeight: 40
              Layout.alignment: Qt.AlignVCenter
              source: creditCard.modelData.icon === "" ? "" : (creditCard.modelData.name === "Noctalia Shell" ? "../../../../../Assets/" + creditCard.modelData.icon : "../../../../../Assets/credits/" + creditCard.modelData.icon)
              fillMode: Image.PreserveAspectFit
              mipmap: true
              smooth: true
              sourceSize.width: 80
              sourceSize.height: 80
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: Style.margin2XS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: creditCard.modelData.name
                  font.weight: Style.fontWeightBold
                  color: cardMouse.containsMouse ? Color.mOnHover : Color.mOnSurface
                }

                NText {
                  visible: creditCard.modelData.license !== ""
                  text: creditCard.modelData.license
                  pointSize: Style.fontSizeS
                  color: cardMouse.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
                  Layout.fillWidth: true
                }

                Item {
                  visible: creditCard.modelData.license === ""
                  Layout.fillWidth: true
                }

                NIcon {
                  icon: "external-link"
                  pointSize: Style.fontSizeM
                  color: cardMouse.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
                }
              }

              NText {
                text: creditCard.modelData.desc
                color: cardMouse.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
              }
            }
          }

          MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["xdg-open", creditCard.modelData.url])
          }
        }
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
  }
}
