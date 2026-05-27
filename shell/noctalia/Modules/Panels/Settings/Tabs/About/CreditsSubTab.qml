import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Widgets

// RYOKU: Credits subtab. Primary attribution to Noctalia (the settings UI is
// adapted from it — required by its MIT license), plus thanks to the other
// upstream projects ryoku draws code and ideas from. Logos in Assets/credits/.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginM
  }

  // --- Primary credit: Noctalia (settings UI) ---
  Image {
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: 88
    Layout.preferredHeight: 88
    source: "../../../../../Assets/noctalia.svg"
    fillMode: Image.PreserveAspectFit
    mipmap: true
    smooth: true
  }

  NHeader {
    Layout.alignment: Qt.AlignHCenter
    label: "Noctalia Shell"
    description: "Settings UI adapted from Noctalia"
  }

  NText {
    Layout.fillWidth: true
    Layout.maximumWidth: 540
    Layout.alignment: Qt.AlignHCenter
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    text: "ryoku's settings interface is adapted, with thanks, from the Noctalia Shell project — © 2025 noctalia-dev, MIT License. Forks and modifications are permitted under that license with proper credit to the original author."
  }

  NButton {
    Layout.alignment: Qt.AlignHCenter
    icon: "github"
    text: "Noctalia on GitHub"
    outlined: true
    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/noctalia-dev/noctalia-shell"])
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
  }

  NHeader {
    label: "With thanks to"
    description: "Projects that inspired or contributed to ryoku"
  }

  // --- Secondary credits (click a card to open its repository) ---
  Repeater {
    model: [
      {
        "name": "Omarchy",
        "desc": "Opinionated Arch / Hyprland system — original base and workflow inspiration.",
        "icon": "omarchy.svg",
        "url": "https://github.com/basecamp/omarchy"
      },
      {
        "name": "Caelestia",
        "desc": "Hyprland / Quickshell desktop shell — design and widget inspiration.",
        "icon": "caelestia.svg",
        "url": "https://github.com/caelestia-dots/shell"
      },
      {
        "name": "illogical-impulse (end-4)",
        "desc": "end-4's usability-first Hyprland shell — design inspiration.",
        "icon": "illogical-impulse.png",
        "url": "https://github.com/end-4/dots-hyprland"
      },
      {
        "name": "iNiR",
        "desc": "Quickshell desktop shell for the Niri compositor — inspiration.",
        "icon": "inir.png",
        "url": "https://github.com/snowarch/iNiR"
      },
      {
        "name": "qylock",
        "desc": "Quickshell lock screen — basis for ryoku's lock screen.",
        "icon": "qylock.png",
        "url": "https://github.com/Darkkal44/qylock"
      },
      {
        "name": "Ambxst",
        "desc": "Quickshell shell — basis for ryoku's dynamic island, weather and tools.",
        "icon": "ambxst.svg",
        "url": "https://github.com/Axenide/Ambxst"
      },
      {
        "name": "skwd-wall",
        "desc": "Aesthetics-first Quickshell wallpaper selector — ryoku's default wallpaper switcher (MIT).",
        "icon": "skwd-wall.svg",
        "url": "https://github.com/liixini/skwd-wall"
      }
    ]

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
          Layout.preferredWidth: 40
          Layout.preferredHeight: 40
          Layout.alignment: Qt.AlignVCenter
          source: "../../../../../Assets/credits/" + creditCard.modelData.icon
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

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
  }
}
