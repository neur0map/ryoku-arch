pragma ComponentBehavior: Bound

import "bluetooth"
import "network"
import "audio"
import "appearance"
import "taskbar"
import "notifications"
import "launcher"
import "dashboard"
import "about"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.controlcenter

ClippingRectangle {
    id: root

    required property Session session

    readonly property bool initialOpeningComplete: stack.initialOpeningComplete
    readonly property var activeEntry: PaneRegistry.getByLabel(session.active)
    readonly property var activeGroupPanes: activeEntry ? PaneRegistry.getByGroup(activeEntry.group) : []

    color: Colours.transparency.enabled ? Colours.layer(Colours.palette.m3surfaceContainer, 1) : Colours.tPalette.m3surface
    clip: true
    focus: false
    activeFocusOnTab: false

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: function (mouse) {
            root.focus = true;
            mouse.accepted = false;
        }
    }

    Connections {
        function onActiveIndexChanged(): void {
            root.focus = true;
        }

        target: root.session
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        RowLayout {
            id: header

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(titleColumn.implicitHeight, activeIcon.implicitHeight)
            spacing: Tokens.spacing.normal

            StyledRect {
                id: activeIcon

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 46
                implicitHeight: 46
                radius: Tokens.rounding.normal
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.activeEntry ? root.activeEntry.icon : "settings"
                    color: Colours.palette.m3onSecondaryContainer
                    font.pointSize: Tokens.font.size.large
                    fill: 1
                }
            }

            ColumnLayout {
                id: titleColumn

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.activeEntry ? root.activeEntry.label : root.session.active
                    font.capitalization: Font.Capitalize
                    font.pointSize: Tokens.font.size.extraLarge
                    font.weight: 650
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.activeEntry ? root.activeEntry.description : ""
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    elide: Text.ElideRight
                }
            }
        }

        Flickable {
            id: tabFlickable

            Layout.fillWidth: true
            Layout.preferredHeight: visible ? tabRow.implicitHeight : 0
            visible: root.activeGroupPanes.length > 1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: tabRow.implicitWidth
            contentHeight: tabRow.implicitHeight
            flickableDirection: Flickable.HorizontalFlick

            RowLayout {
                id: tabRow

                spacing: Tokens.spacing.small

                Repeater {
                    model: root.activeGroupPanes

                    StyledRect {
                        id: tab

                        required property var modelData
                        readonly property bool active: root.session.active === modelData.label

                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: tabContent.implicitWidth + Tokens.padding.normal * 2
                        implicitHeight: tabContent.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainer

                        StateLayer {
                            onClicked: {
                                if (!root.initialOpeningComplete)
                                    return;

                                root.session.active = tab.modelData.label;
                            }

                            color: tab.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            radius: tab.radius
                        }

                        RowLayout {
                            id: tabContent

                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                text: tab.modelData.icon
                                color: tab.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                fill: tab.active ? 1 : 0
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                text: tab.modelData.label
                                color: tab.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                font.capitalization: Font.Capitalize
                                font.weight: tab.active ? 600 : 500
                            }
                        }
                    }
                }
            }
        }

        ClippingRectangle {
            id: viewport

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: Colours.transparency.enabled ? Colours.layer(Colours.palette.m3surfaceContainer, 1) : Colours.tPalette.m3surfaceContainerLow
            clip: true

            ColumnLayout {
                id: stack

                property bool animationComplete: true
                property bool initialOpeningComplete: false

                spacing: 0
                y: -root.session.activeIndex * viewport.height
                clip: true

                Timer {
                    id: animationDelayTimer

                    interval: Tokens.anim.durations.normal
                    onTriggered: {
                        stack.animationComplete = true;
                    }
                }

                Timer {
                    id: initialOpeningTimer

                    interval: Tokens.anim.durations.large
                    running: true
                    onTriggered: {
                        stack.initialOpeningComplete = true;
                    }
                }

                Repeater {
                    model: PaneRegistry.count

                    Pane {
                        required property int index

                        paneIndex: index
                        componentPath: PaneRegistry.getByIndex(index).component
                    }
                }

                Behavior on y {
                    Anim {}
                }

                Connections {
                    function onActiveIndexChanged(): void {
                        stack.animationComplete = false;
                        animationDelayTimer.restart();
                    }

                    target: root.session
                }
            }
        }
    }

    component Pane: Item {
        id: pane

        required property int paneIndex
        required property string componentPath
        property bool hasBeenLoaded: false

        function updateActive(): void {
            const diff = Math.abs(root.session.activeIndex - pane.paneIndex);
            const isActivePane = diff === 0;
            let shouldBeActive = false;

            if (!stack.initialOpeningComplete) {
                shouldBeActive = isActivePane;
            } else {
                if (diff <= 1) {
                    shouldBeActive = true;
                } else if (pane.hasBeenLoaded) {
                    shouldBeActive = true;
                } else {
                    shouldBeActive = stack.animationComplete;
                }
            }

            loader.active = shouldBeActive;
        }

        implicitWidth: viewport.width
        implicitHeight: viewport.height

        Loader {
            id: loader

            anchors.fill: parent
            asynchronous: true
            clip: false
            active: false

            Component.onCompleted: {
                Qt.callLater(pane.updateActive);
            }

            onActiveChanged: {
                if (active && !pane.hasBeenLoaded) {
                    pane.hasBeenLoaded = true;
                }

                if (active && !item) {
                    loader.setSource(pane.componentPath, {
                        "session": root.session
                    });
                }
            }

            onItemChanged: {
                if (item) {
                    pane.hasBeenLoaded = true;
                }
            }
        }

        Connections {
            function onActiveIndexChanged(): void {
                pane.updateActive();
            }

            target: root.session
        }

        Connections {
            function onInitialOpeningCompleteChanged(): void {
                pane.updateActive();
            }
            function onAnimationCompleteChanged(): void {
                pane.updateActive();
            }

            target: stack
        }
    }
}
