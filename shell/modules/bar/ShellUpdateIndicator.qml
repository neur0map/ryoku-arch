import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Compact Ryoku shell update indicator for the bar.
 * Shows when a new version is available in the git repo, and handles live update progress.
 */
MouseArea {
    id: root

    property bool compact: false

    visible: ShellUpdates.showUpdate || ShellUpdates.isUpdating
    implicitWidth: visible ? pill.width : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: ShellUpdates.isUpdating ? Qt.ArrowCursor : Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    readonly property color accentColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary
    readonly property int horizontalPadding: root.compact ? 6 : 8
    readonly property int contentSpacing: root.compact ? 4 : 5
    readonly property int updatePopupWidth: 380
    readonly property int popupRowSpacing: 8
    readonly property int popupDetailSpacing: 6
    readonly property color popupTextColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer2
    readonly property color popupSubtextColor: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary
        : Appearance.colors.colSubtext

    onClicked: (mouse) => {
        if (ShellUpdates.isUpdating) return;
        
        if (mouse.button === Qt.RightButton) {
            ShellUpdates.dismiss()
        } else {
            ShellUpdates.openOverlay()
        }
    }

    // Background pill
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: contentRow.implicitWidth + (root.horizontalPadding * 2)
        height: contentRow.implicitHeight + 8
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : height / 2
        scale: (!ShellUpdates.isUpdating && root.pressed) ? 0.93 : ((!ShellUpdates.isUpdating && root.containsMouse) ? 1.03 : 1.0)
        color: {
            if (ShellUpdates.isUpdating) {
                if (Appearance.angelEverywhere) return ColorUtils.transparentize(Appearance.angel.colPrimary, 0.92)
                if (Appearance.ryokuEverywhere) return ColorUtils.transparentize(Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary, 0.92)
                if (Appearance.auroraEverywhere) return ColorUtils.transparentize(Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary, 0.92)
                return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.92)
            }
            if (root.pressed) {
                if (Appearance.angelEverywhere) return Appearance.angel.colGlassCardActive
                if (Appearance.ryokuEverywhere) return Appearance.ryoku.colLayer2Active
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurfaceActive
                return Appearance.colors.colLayer1Active
            }
            if (root.containsMouse) {
                if (Appearance.angelEverywhere) return Appearance.angel.colGlassCardHover
                if (Appearance.ryokuEverywhere) return Appearance.ryoku.colLayer1Hover
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurface
                return Appearance.colors.colLayer1Hover
            }
            if (Appearance.angelEverywhere) return ColorUtils.transparentize(Appearance.angel.colPrimary, 0.85)
            if (Appearance.ryokuEverywhere) return ColorUtils.transparentize(Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            if (Appearance.auroraEverywhere) return ColorUtils.transparentize(Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.88)
        }

        border.width: (Appearance.angelEverywhere || Appearance.ryokuEverywhere) ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.ryokuEverywhere ? Appearance.ryoku.colBorder : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: pill
        spacing: root.contentSpacing

        MaterialSymbol {
            id: updateIcon
            text: ShellUpdates.isUpdating ? "progress_activity" : "upgrade"
            iconSize: Appearance.font.pixelSize.normal
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter

            RotationAnimation on rotation {
                loops: Animation.Infinite
                running: ShellUpdates.isUpdating
                from: 0
                to: 360
                duration: 1200
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !ShellUpdates.isUpdating && root.containsMouse
                NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            text: {
                if (ShellUpdates.isUpdating) {
                    if (ShellUpdates.updateStep > 0 && ShellUpdates.updateTotalSteps > 0) {
                        return ShellUpdates.updateStep + "/" + ShellUpdates.updateTotalSteps
                    }
                    return "" // Just spinner if no steps known
                }
                return ShellUpdates.commitsBehind > 0
                    ? ShellUpdates.commitsBehind.toString()
                    : "!"
            }
            visible: text !== ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Hover popup follows the StyledPopup rich-tooltip pattern in
    // docs/ui-patterns.md: padding lives on StyledPopup and content is anchored
    // inside the padded surface.
    StyledPopup {
        id: updatePopup
        hoverTarget: root
        horizontalPadding: 16
        verticalPadding: 12
        colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassTooltip
            : Appearance.ryokuEverywhere ? Appearance.ryoku.colTooltip
            : Appearance.colors.colLayer2
        colBorder: Appearance.angelEverywhere ? Appearance.angel.colTooltipBorder
            : Appearance.ryokuEverywhere ? Appearance.ryoku.colTooltipBorder
            : Appearance.colors.colLayer2Hover

        Item {
            id: updatePopupContent
            anchors.centerIn: parent
            implicitWidth: root.updatePopupWidth
            implicitHeight: popupContentColumn.implicitHeight
            width: implicitWidth
            height: implicitHeight

            ColumnLayout {
                id: popupContentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.popupRowSpacing

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        fill: 0
                        font.weight: Font.Medium
                        text: ShellUpdates.isUpdating ? "progress_activity" : "deployed_code_update"
                        iconSize: Appearance.font.pixelSize.large
                        color: root.popupTextColor

                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            running: ShellUpdates.isUpdating && updatePopup.active
                            from: 0
                            to: 360
                            duration: 1200
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: ShellUpdates.isUpdating ? Translation.tr("Updating...") : Translation.tr("Ryoku Update")
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.normal
                        }
                        color: root.popupTextColor
                    }
                }

                RowLayout {
                    visible: ShellUpdates.isUpdating
                    spacing: root.popupDetailSpacing
                    Layout.fillWidth: true

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        text: "info"
                        iconSize: Appearance.font.pixelSize.large
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: ShellUpdates.updateStepMessage.length > 0 ? Translation.tr(ShellUpdates.updateStepMessage) : Translation.tr("Processing...")
                        color: root.popupTextColor
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        visible: ShellUpdates.updateStep > 0 && ShellUpdates.updateTotalSteps > 0
                        text: Translation.tr("Step") + " " + ShellUpdates.updateStep + "/" + ShellUpdates.updateTotalSteps
                        color: root.popupTextColor
                        font.weight: Font.DemiBold
                    }
                }

                RowLayout {
                    visible: !ShellUpdates.isUpdating
                    spacing: root.popupDetailSpacing
                    Layout.fillWidth: true

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        text: "download"
                        iconSize: Appearance.font.pixelSize.large
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Behind:")
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: ShellUpdates.commitsBehind > 0
                            ? (ShellUpdates.commitsBehind + " " + Translation.tr("commit(s)"))
                            : Translation.tr("Update available")
                        color: ShellUpdates.commitsBehind > 10
                            ? (Appearance.m3colors?.m3error ?? root.popupTextColor)
                            : root.popupTextColor
                        font.weight: Font.Medium
                    }
                }

                RowLayout {
                    visible: !ShellUpdates.isUpdating && ShellUpdates.localVersion.length > 0 && ShellUpdates.remoteVersion.length > 0 && ShellUpdates.remoteVersion !== ShellUpdates.localVersion
                    spacing: root.popupDetailSpacing
                    Layout.fillWidth: true

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        text: "tag"
                        iconSize: Appearance.font.pixelSize.large
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Version:")
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        text: "v" + ShellUpdates.localVersion + "  →  v" + ShellUpdates.remoteVersion
                        font {
                            family: Appearance.font.family.monospace
                            weight: Font.Medium
                        }
                        color: root.popupTextColor
                    }
                }

                RowLayout {
                    visible: !ShellUpdates.isUpdating
                    spacing: root.popupDetailSpacing
                    Layout.fillWidth: true

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        text: "commit"
                        iconSize: Appearance.font.pixelSize.large
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Commit:")
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        text: (ShellUpdates.localCommit || "\u2014") +
                            (ShellUpdates.remoteCommit.length > 0 ? ("  →  " + ShellUpdates.remoteCommit) : "")
                        font {
                            family: Appearance.font.family.monospace
                            weight: Font.Medium
                        }
                        color: root.popupTextColor
                    }
                }

                RowLayout {
                    visible: !ShellUpdates.isUpdating && ShellUpdates.currentBranch.length > 0
                    spacing: root.popupDetailSpacing
                    Layout.fillWidth: true

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        text: "account_tree"
                        iconSize: Appearance.font.pixelSize.large
                        color: ShellUpdates.isNonMainBranch
                            ? Appearance.m3colors.m3tertiary
                            : root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Branch:")
                        color: root.popupSubtextColor
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        text: ShellUpdates.currentBranch
                        font.family: Appearance.font.family.monospace
                        color: ShellUpdates.isNonMainBranch
                            ? Appearance.m3colors.m3tertiary
                            : root.popupTextColor
                    }
                }

                StyledText {
                    visible: ShellUpdates.isNonMainBranch && !ShellUpdates.isUpdating
                    Layout.fillWidth: true
                    text: Translation.tr("You are on a non-release branch. Updates track this branch.")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors.m3tertiary
                    wrapMode: Text.WordWrap
                    opacity: 0.85
                }

                RowLayout {
                    spacing: root.popupDetailSpacing
                    visible: !ShellUpdates.isUpdating && ShellUpdates.lastError.length > 0
                    Layout.fillWidth: true

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        text: "error"
                        color: Appearance.m3colors?.m3error ?? root.popupTextColor
                        iconSize: Appearance.font.pixelSize.large
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: ShellUpdates.lastError
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.m3colors?.m3error ?? root.popupTextColor
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    visible: !ShellUpdates.isUpdating
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                        : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colBorder ?? Appearance.colors.colLayer0Border)
                        : Appearance.colors.colLayer0Border
                    opacity: 0.5
                }

                StyledText {
                    visible: !ShellUpdates.isUpdating
                    Layout.fillWidth: true
                    text: Translation.tr("Click for details · Right-click to dismiss")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.popupSubtextColor
                    opacity: 0.72
                    elide: Text.ElideRight
                }
            }
        }
    }
}
