import QtQuick
import Ryoku.Config
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

Item {
  id: root

  required property real percentage
  required property bool charging
  required property bool pluggedIn
  required property bool ready
  required property bool low
  required property bool critical

  property real baseSize: Style.fontSizeM

  property color baseColor: Color.mOnSurface
  property color lowColor: Color.mError
  property color chargingColor: Color.mPrimary
  property color textColor: Color.mSurface

  property bool showPercentageText: true
  property bool vertical: false

  property bool showStateIcon: false

  onChargingChanged: {
    if (!charging)
      showStateIcon = false;
  }

  readonly property real scaleFactor: baseSize / Style.fontSizeM
  readonly property real bodyWidth: {
    const min = Style.toOdd(22 * scaleFactor);
    if (!showPercentageText) {
      return min;
    }

    if (percentage > 99) {
      const max = Style.toOdd(30 * scaleFactor);
      return max;
    }
    return min;
  }

  readonly property real bodyHeight: Style.toOdd(14 * scaleFactor)
  readonly property real terminalWidth: Math.round(2.5 * scaleFactor)
  readonly property real terminalHeight: Math.round(7 * scaleFactor)
  readonly property real cornerRadius: Math.round(3 * scaleFactor)

  readonly property real totalWidth: vertical ? bodyHeight : bodyWidth + terminalWidth
  readonly property real totalHeight: vertical ? bodyWidth + terminalWidth : bodyHeight

  readonly property color activeColor: {
    if (!ready) {
      return Qt.alpha(baseColor, Style.opacityMedium);
    }
    if (charging) {
      return chargingColor;
    }
    if (low || critical) {
      return lowColor;
    }
    return baseColor;
  }

  readonly property color emptyColor: Qt.alpha(baseColor, 0.66)

  readonly property string stateIcon: {
    if (!ready)
      return "x";
    if (charging)
      return "bolt-filled";
    if (pluggedIn)
      return "plug-filled";
    return "";
  }

  property real animatedPercentage: percentage

  Behavior on animatedPercentage {
    enabled: !GlobalConfig.appearance.reduceMotion
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Timer {
    id: alternateTimer
    interval: 4000
    repeat: true
    running: root.charging && root.showPercentageText
    onTriggered: root.showStateIcon = !root.showStateIcon
  }

  implicitWidth: Math.round(totalWidth)
  implicitHeight: Math.round(totalHeight)
  Layout.maximumWidth: implicitWidth
  Layout.maximumHeight: implicitHeight

  Item {
    id: batteryBody
    width: root.vertical ? root.bodyHeight : root.bodyWidth + root.terminalWidth
    height: root.vertical ? root.bodyWidth + root.terminalWidth : root.bodyHeight
    anchors.left: root.vertical ? undefined : parent.left
    anchors.bottom: root.vertical ? parent.bottom : undefined
    anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
    anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter

    Rectangle {
      id: bodyBackground
      y: root.vertical ? root.terminalWidth : 0
      width: root.vertical ? root.bodyHeight : root.bodyWidth
      height: root.vertical ? root.bodyWidth : root.bodyHeight
      radius: root.cornerRadius
      color: root.emptyColor
    }

    Rectangle {
      x: root.vertical ? (root.bodyHeight - root.terminalHeight) / 2 : root.bodyWidth
      y: root.vertical ? 0 : (root.bodyHeight - root.terminalHeight) / 2
      width: root.vertical ? root.terminalHeight : root.terminalWidth
      height: root.vertical ? root.terminalWidth : root.terminalHeight
      radius: root.cornerRadius / 2
      color: root.critical ? root.lowColor : root.emptyColor
    }

    Rectangle {
      id: fillRect
      visible: root.ready && (root.animatedPercentage > 0 || root.critical)
      x: 0
      y: root.vertical ? root.terminalWidth + root.bodyWidth * (1 - (root.critical ? 1 : root.animatedPercentage / 100)) : 0
      width: root.vertical ? root.bodyHeight : root.bodyWidth * (root.critical ? 1 : root.animatedPercentage / 100)
      height: root.vertical ? root.bodyWidth * (root.critical ? 1 : root.animatedPercentage / 100) : root.bodyHeight
      radius: root.cornerRadius
      color: root.activeColor
    }
  }

  NText {
    id: percentageText
    visible: opacity > 0
    opacity: root.showPercentageText && root.ready && (root.charging ? !root.showStateIcon : !root.pluggedIn) ? 1 : 0
    x: batteryBody.x + Style.pixelAlignCenter(bodyBackground.width, width)
    y: batteryBody.y + bodyBackground.y + Style.pixelAlignCenter(bodyBackground.height, height)
    font.family: Settings.data.ui.fontFixed
    font.weight: Style.fontWeightBold
    text: root.vertical ? String(Math.round(root.animatedPercentage)).split('').join('\n') : Math.round(root.animatedPercentage)
    pointSize: root.baseSize * (root.vertical ? 0.82 : 0.82)
    color: Qt.alpha(root.textColor, 0.75)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    lineHeight: root.vertical ? 0.7 : 1.0
    lineHeightMode: Text.ProportionalHeight

    Behavior on opacity {
      enabled: !GlobalConfig.appearance.reduceMotion
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }
  }

  NIcon {
    id: stateIconOverlay
    visible: opacity > 0
    opacity: !root.ready || (root.charging ? (root.showStateIcon || !root.showPercentageText) : root.pluggedIn) ? 1 : 0
    x: batteryBody.x + Style.pixelAlignCenter(bodyBackground.width, width)
    y: batteryBody.y + bodyBackground.y + Style.pixelAlignCenter(bodyBackground.height, height)
    icon: root.stateIcon
    pointSize: Style.toOdd(root.baseSize)
    color: Qt.alpha(root.textColor, 0.75)

    Behavior on opacity {
      enabled: !GlobalConfig.appearance.reduceMotion
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }
  }
}
