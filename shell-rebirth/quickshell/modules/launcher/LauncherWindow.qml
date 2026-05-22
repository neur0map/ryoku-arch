import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../colors" as ColorsModule
import qs.services as Services

Item {
    id: root

    property bool isOpen: false
    property string searchText: ""

    property var filteredApps: {
        const q = searchText.trim().toLowerCase()
        if (!q) return Services.AppRegistry.apps
        return Services.AppRegistry.apps.filter(app =>
            app.name.toLowerCase().includes(q) ||
            (app.comment && app.comment.toLowerCase().includes(q))
        )
    }

    function toggle() {
        if (isOpen) close()
        else open()
    }

    function open() {
        if (isOpen) return
        isOpen = true
        searchField.text = ""

        backdrop.opacity   = 0
        searchPill.opacity = 0
        searchPill.y       = searchPill._targetY - 28
        gridContainer.opacity = 0
        hintText.opacity   = 0

        openAnim.restart()
        searchField.forceActiveFocus()
    }

    function close() {
        if (!isOpen) return
        closeAnim.restart()
    }

    anchors.fill: parent
    enabled: isOpen

    // ── Backdrop ─────────────────────────────────────────────────────────────

    Rectangle {
        id: backdrop
        anchors.fill: parent
        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.88) }
            GradientStop { position: 0.42; color: Qt.rgba(0, 0, 0, 0.74) }
            GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.88) }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    // ── Search pill ───────────────────────────────────────────────────────────

    Item {
        id: searchPill
        anchors.horizontalCenter: parent.horizontalCenter

        property real _targetY: 100
        y: _targetY

        width: 520
        height: 56
        opacity: 0

        Rectangle {
            anchors.fill: parent
            radius: 28

            color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1.5
            border.color: searchField.activeFocus
                ? Qt.rgba(
                    Qt.color(ColorsModule.Colors.primary).r,
                    Qt.color(ColorsModule.Colors.primary).g,
                    Qt.color(ColorsModule.Colors.primary).b,
                    0.5
                  )
                : Qt.rgba(1, 1, 1, 0.12)

            // Top-edge shine
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.5
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.055) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Behavior on border.color { ColorAnimation { duration: 200 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 16
                spacing: 14

                Text {
                    text: "󰍉"
                    font.family: "Material Design Icons"
                    font.pixelSize: 20
                    color: searchField.activeFocus
                        ? ColorsModule.Colors.primary
                        : Qt.rgba(1, 1, 1, 0.4)
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    placeholderText: "SEARCH APPLICATIONS"
                    font.pixelSize: 13
                    font.family: "Noto Sans"
                    font.letterSpacing: 1.5
                    color: "white"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.28)

                    background: Item {}
                    leftPadding: 0
                    rightPadding: 0

                    onTextChanged: root.searchText = text

                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: {
                        if (root.filteredApps.length > 0)
                            launchApp(root.filteredApps[gridView.currentIndex >= 0 ? gridView.currentIndex : 0])
                    }
                    Keys.onDownPressed: gridView.forceActiveFocus()
                }

                Rectangle {
                    visible: searchField.text.length > 0
                    width: 26; height: 26; radius: 13
                    color: clearArea.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.15)
                        : Qt.rgba(1, 1, 1, 0.08)
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "Material Design Icons"
                        font.pixelSize: 14
                        color: Qt.rgba(1, 1, 1, 0.65)
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchField.text = ""
                    }
                }
            }
        }
    }

    // ── App grid ──────────────────────────────────────────────────────────────

    Item {
        id: gridContainer
        anchors.top: searchPill.bottom
        anchors.topMargin: 32
        anchors.bottom: hintText.top
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: 1200
        opacity: 0

        GridView {
            id: gridView
            anchors.fill: parent
            anchors.rightMargin: 4

            cellWidth:  130
            cellHeight: 138
            clip: true

            model: root.filteredApps

            Keys.onReturnPressed: {
                if (currentIndex >= 0 && currentIndex < root.filteredApps.length)
                    launchApp(root.filteredApps[currentIndex])
            }
            Keys.onEscapePressed: root.close()
            Keys.onUpPressed: {
                if (currentIndex < gridView.columns)
                    searchField.forceActiveFocus()
                else
                    moveCurrentIndexUp()
            }

            delegate: Item {
                id: delegateRoot
                width: gridView.cellWidth
                height: gridView.cellHeight

                property var app: root.filteredApps[index]
                property bool isHovered: false
                property bool isFocused: GridView.isCurrentItem
                property bool isPressed: false

                opacity: 0
                Component.onCompleted: {
                    scale = 0.80
                    entranceAnim.start()
                }

                ParallelAnimation {
                    id: entranceAnim
                    running: false
                    NumberAnimation {
                        target: delegateRoot; property: "opacity"
                        from: 0; to: 1; duration: 260
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: delegateRoot; property: "scale"
                        from: 0.80; to: 1; duration: 300
                        easing.type: Easing.OutBack; easing.overshoot: 0.5
                    }
                }

                // Inner content centered in cell
                Item {
                    anchors.centerIn: parent
                    width: 88
                    height: 116

                    // Outer glow ring — visible on hover/focus
                    Rectangle {
                        anchors.centerIn: iconFrame
                        width: iconFrame.width + 20
                        height: iconFrame.height + 20
                        radius: 24
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(
                            Qt.color(ColorsModule.Colors.primary).r,
                            Qt.color(ColorsModule.Colors.primary).g,
                            Qt.color(ColorsModule.Colors.primary).b,
                            delegateRoot.isHovered || delegateRoot.isFocused ? 0.45 : 0
                        )
                        scale: delegateRoot.isHovered || delegateRoot.isFocused ? 1.0 : 0.75

                        Behavior on border.color { ColorAnimation  { duration: 200 } }
                        Behavior on scale        { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }

                    // Icon frame
                    Rectangle {
                        id: iconFrame
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72
                        height: 72
                        radius: 20

                        color: Qt.rgba(1, 1, 1,
                            delegateRoot.isPressed ? 0.20
                            : delegateRoot.isHovered || delegateRoot.isFocused ? 0.13
                            : 0.07)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1,
                            delegateRoot.isHovered || delegateRoot.isFocused ? 0.22 : 0.09)

                        scale: delegateRoot.isPressed ? 0.86
                            : delegateRoot.isHovered  ? 1.10 : 1.0

                        // Top-edge shine
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * 0.5
                            radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 44; height: 44
                            sourceSize.width: 88; sourceSize.height: 88
                            source: Services.AppRegistry.iconForAppMeta(delegateRoot.app)
                            fillMode: Image.PreserveAspectFit
                            smooth: true; antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: ColorsModule.Colors.primary_container
                                visible: parent.status === Image.Error || parent.status === Image.Null

                                Text {
                                    anchors.centerIn: parent
                                    text: delegateRoot.app && delegateRoot.app.name
                                        ? delegateRoot.app.name.charAt(0).toUpperCase() : "?"
                                    font.pixelSize: 20
                                    font.weight: Font.Medium
                                    color: ColorsModule.Colors.on_primary_container
                                }
                            }
                        }

                        Behavior on color        { ColorAnimation  { duration: 150 } }
                        Behavior on border.color { ColorAnimation  { duration: 150 } }
                        Behavior on scale        { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                    }

                    // Label — PowerMenu style: all-caps, spaced, dim until hovered
                    Text {
                        anchors.top: iconFrame.bottom
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width + 24
                        text: delegateRoot.app ? delegateRoot.app.name.toUpperCase() : ""
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        font.letterSpacing: 1.5
                        color: Qt.rgba(1, 1, 1,
                            delegateRoot.isHovered || delegateRoot.isFocused ? 0.88 : 0.38)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { delegateRoot.isHovered = true; gridView.currentIndex = index }
                        onExited:  { delegateRoot.isHovered = false; delegateRoot.isPressed = false }
                        onPressed: delegateRoot.isPressed = true
                        onReleased: delegateRoot.isPressed = false
                        onClicked: launchApp(root.filteredApps[index])
                    }
                }
            }

            // ── Empty state ───────────────────────────────────────────────────

            Column {
                anchors.centerIn: parent
                visible: root.filteredApps.length === 0
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰍉"
                    font.family: "Material Design Icons"
                    font.pixelSize: 34
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO RESULTS"
                    font.pixelSize: 10
                    font.letterSpacing: 3.5
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.22)
                }
            }
        }
    }

    // ── Hint ─────────────────────────────────────────────────────────────────

    Text {
        id: hintText
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 52
        text: "ESC TO CANCEL"
        font.pixelSize: 10
        font.letterSpacing: 2.5
        font.weight: Font.Light
        color: Qt.rgba(1, 1, 1, 0.2)
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }

    // ── Open animation ────────────────────────────────────────────────────────

    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: backdrop; property: "opacity"
            to: 1; duration: 240; easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: 50 }
            ParallelAnimation {
                NumberAnimation {
                    target: searchPill; property: "opacity"
                    to: 1; duration: 300; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: searchPill; property: "y"
                    to: searchPill._targetY; duration: 380; easing.type: Easing.OutCubic
                }
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 110 }
            NumberAnimation {
                target: gridContainer; property: "opacity"
                to: 1; duration: 300; easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 440 }
            NumberAnimation {
                target: hintText; property: "opacity"
                to: 1; duration: 260; easing.type: Easing.OutCubic
            }
        }
    }

    // ── Close animation ───────────────────────────────────────────────────────

    ParallelAnimation {
        id: closeAnim

        NumberAnimation {
            target: backdrop; property: "opacity"
            to: 0; duration: 200; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: searchPill; property: "opacity"
            to: 0; duration: 180; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: gridContainer; property: "opacity"
            to: 0; duration: 180; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: hintText; property: "opacity"
            to: 0; duration: 160; easing.type: Easing.InCubic
        }

        onFinished: root.isOpen = false
    }

    // ── Launch ────────────────────────────────────────────────────────────────

    function launchApp(app) {
        if (!app || !app.exec) return
        const cmd = app.exec.replace(/%[uUfFdDnNickvm]/g, "").trim()
        launcher.command = ["bash", "-c", cmd]
        launcher.running = true
        root.close()
    }

    Process {
        id: launcher
        running: false
    }
}
