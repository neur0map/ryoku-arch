import QtQuick
import QtQuick.Effects
import qs.ambxst.modules.theme
import qs.ambxst.modules.corners
import qs.ambxst.modules.components
import qs.ambxst.config

Item {
    id: root
    required property string position

    default property alias content: contentContainer.data

    // Item should be always visible to allow children (widgets) to render
    // even if background is hidden.
    visible: true

    readonly property bool effectiveContainBar: Config.bar.containBar && (Config.bar.frameEnabled ?? false)

    readonly property int cornerSize: (Config.theme.enableCorners && !effectiveContainBar && root.outerMargin === 0) ? Styling.radius(4) : 0
    readonly property bool isHorizontal: position === "top" || position === "bottom"
    readonly property bool cornersVisible: Config.theme.enableCorners && cornerSize > 0

    readonly property real bgOpacity: Config.theme.srBarBg.opacity
    readonly property int padding: bgOpacity < 0.01 ? 0 : 4

    readonly property int outerMargin: !effectiveContainBar ? 4 : 0

    StyledRect {
        id: barBackground
        variant: "barbg"
        visible: Config.showBackground
        radius: Styling.radius(effectiveContainBar ? 4 : 0)
        enableBorder: !effectiveContainBar || (Config.bar.keepBarBorder ?? false)

        x: (position === "right") ? -cornerSize : 0
        y: (position === "bottom") ? -cornerSize : 0
        width: root.width + (isHorizontal ? 0 : cornerSize)
        height: root.height + (isHorizontal ? cornerSize : 0)

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: barMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.padding
    }

    Item {
        id: barMask
        visible: false
        x: barBackground.x
        y: barBackground.y
        width: barBackground.width
        height: barBackground.height
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            id: centerMask
            color: "white"
            x: root.position === "right" ? cornerSize : 0
            y: root.position === "bottom" ? cornerSize : 0
            width: root.width
            height: root.height
        }

        Item {
            id: cornerLeftMask
            width: cornerSize
            height: cornerSize

            states: [
                State {
                    name: "top"
                    when: root.position === "top"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: 0
                        y: root.height
                    }
                },
                State {
                    name: "bottom"
                    when: root.position === "bottom"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: 0
                        y: 0
                    }
                },
                State {
                    name: "left"
                    when: root.position === "left"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: root.width
                        y: 0
                    }
                },
                State {
                    name: "right"
                    when: root.position === "right"
                    PropertyChanges {
                        target: cornerLeftMask
                        x: 0
                        y: 0
                    }
                }
            ]

            RoundCorner {
                anchors.fill: parent
                corner: {
                    if (root.position === "top")
                        return RoundCorner.CornerEnum.TopLeft;
                    if (root.position === "bottom")
                        return RoundCorner.CornerEnum.BottomLeft;
                    if (root.position === "left")
                        return RoundCorner.CornerEnum.TopLeft;
                    if (root.position === "right")
                        return RoundCorner.CornerEnum.TopRight;
                }
                size: Math.max(cornerSize, 1)
                color: "white"
            }
        }

        Item {
            id: cornerRightMask
            width: cornerSize
            height: cornerSize

            states: [
                State {
                    name: "top"
                    when: root.position === "top"
                    PropertyChanges {
                        target: cornerRightMask
                        x: root.width - cornerSize
                        y: root.height
                    }
                },
                State {
                    name: "bottom"
                    when: root.position === "bottom"
                    PropertyChanges {
                        target: cornerRightMask
                        x: root.width - cornerSize
                        y: 0
                    }
                },
                State {
                    name: "left"
                    when: root.position === "left"
                    PropertyChanges {
                        target: cornerRightMask
                        x: root.width
                        y: root.height - cornerSize
                    }
                },
                State {
                    name: "right"
                    when: root.position === "right"
                    PropertyChanges {
                        target: cornerRightMask
                        x: 0
                        y: root.height - cornerSize
                    }
                }
            ]

            RoundCorner {
                anchors.fill: parent
                corner: {
                    if (root.position === "top")
                        return RoundCorner.CornerEnum.TopRight;
                    if (root.position === "bottom")
                        return RoundCorner.CornerEnum.BottomRight;
                    if (root.position === "left")
                        return RoundCorner.CornerEnum.BottomLeft;
                    if (root.position === "right")
                        return RoundCorner.CornerEnum.BottomRight;
                }
                size: Math.max(cornerSize, 1)
                color: "white"
            }
        }
    }
}
