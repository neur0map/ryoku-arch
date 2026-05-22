import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../colors" as ColorsModule

Item {
    id: root

    implicitWidth:  740
    implicitHeight: 310
    focus: true
    property int  totalSeconds:     0
    property int  remainingSeconds: 0
    property bool running:          false
    property bool finished:         false
    property real progress:         totalSeconds > 0
        ? (1 - remainingSeconds / totalSeconds)
        : 0

    function pad(n) { return n < 10 ? "0" + n : "" + n }

    function displayTime(secs) {
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        return pad(h) + ":" + pad(m) + ":" + pad(s)
    }

    function startTimer() {
        var h = parseInt(hoursField.text)   || 0
        var m = parseInt(minutesField.text) || 0
        var s = parseInt(secondsField.text) || 0
        var total = h * 3600 + m * 60 + s
        if (total <= 0) return
        totalSeconds     = total
        remainingSeconds = total
        finished         = false
        running          = true
    }

    function resetTimer() {
        running          = false
        finished         = false
        remainingSeconds = 0
        totalSeconds     = 0
        hoursField.text   = ""
        minutesField.text = ""
        secondsField.text = ""
    }

    function sendNotification() {
        var msg = notifField.text.trim() !== "" ? notifField.text : "Timer finished!"
        Quickshell.execDetached(["notify-send", "-a", "Quickshell Timer", "\u23f0 Timer Done", msg])
    }

    Timer {
        interval: 1000
        repeat:   true
        running:  root.running
        onTriggered: {
            if (root.remainingSeconds > 0) {
                root.remainingSeconds--
            } else {
                root.running  = false
                root.finished = true
                root.sendNotification()
            }
        }
    }

    // Background glow effect when finished
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: "transparent"
        border.width: 0

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.finished ? Qt.rgba(
                ColorsModule.Colors.tertiary.r,
                ColorsModule.Colors.tertiary.g,
                ColorsModule.Colors.tertiary.b,
                0.05
            ) : "transparent"

            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    RowLayout {
        anchors.fill:    parent
        anchors.margins: 20
        spacing:         32


        Item {
            Layout.preferredWidth:  200
            Layout.preferredHeight: 200
            Layout.alignment:       Qt.AlignVCenter

            // Outer glow ring for finished state
            Rectangle {
                anchors.centerIn: parent
                width: 192
                height: 192
                radius: 96
                color: "transparent"
                border.width: root.finished ? 2 : 0
                border.color: Qt.rgba(
                    ColorsModule.Colors.tertiary.r,
                    ColorsModule.Colors.tertiary.g,
                    ColorsModule.Colors.tertiary.b,
                    0.3
                )
                opacity: root.finished ? 0.5 : 0

                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on border.width { NumberAnimation { duration: 300 } }
            }

            // Background track with subtle gradient
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, 88, 0, Math.PI * 2)
                    ctx.strokeStyle = ColorsModule.Colors.surface_container_highest
                    ctx.lineWidth   = 6
                    ctx.stroke()

                    // Add subtle inner track
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, 82, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(
                        ColorsModule.Colors.surface_container_highest.r,
                        ColorsModule.Colors.surface_container_highest.g,
                        ColorsModule.Colors.surface_container_highest.b,
                        0.3
                    )
                    ctx.lineWidth   = 1
                    ctx.stroke()
                }
            }

            // Progress arc with glow effect
            Canvas {
                id:           arcCanvas
                anchors.fill: parent

                Connections {
                    target: root
                    function onProgressChanged() { arcCanvas.requestPaint() }
                    function onFinishedChanged()  { arcCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    if (root.progress <= 0 && !root.finished) return

                    // Draw glow for finished state
                    if (root.finished) {
                        ctx.beginPath()
                        ctx.arc(width / 2, height / 2, 94, 0, Math.PI * 2)
                        ctx.strokeStyle = Qt.rgba(
                            ColorsModule.Colors.tertiary.r,
                            ColorsModule.Colors.tertiary.g,
                            ColorsModule.Colors.tertiary.b,
                            0.2
                        )
                        ctx.lineWidth   = 12
                        ctx.stroke()
                    }

                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, 88,
                        -Math.PI / 2,
                        -Math.PI / 2 + (root.finished ? Math.PI * 2 : root.progress * Math.PI * 2))
                    ctx.strokeStyle = root.finished
                        ? ColorsModule.Colors.tertiary
                        : ColorsModule.Colors.primary
                    ctx.lineWidth   = root.finished ? 8 : 6
                    ctx.lineCap     = "round"
                    ctx.stroke()
                }
            }

            // Time display with better typography
            Text {
                anchors.centerIn: parent
                text: (root.running || root.finished || root.remainingSeconds > 0)
                    ? root.displayTime(root.remainingSeconds)
                    : "00:00:00"
                font.pixelSize:  32
                font.weight:     Font.Light
                font.family:     "monospace"
                color: root.finished
                    ? ColorsModule.Colors.tertiary
                    : ColorsModule.Colors.on_surface

                // Removed layer effect as it might not be available
            }

            // "done" badge with improved styling
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom:           parent.bottom
                anchors.bottomMargin:     16
                visible:                  root.finished

                width: 60
                height: 24
                radius: 12
                color: Qt.rgba(
                    ColorsModule.Colors.tertiary.r,
                    ColorsModule.Colors.tertiary.g,
                    ColorsModule.Colors.tertiary.b,
                    0.15
                )

                Text {
                    anchors.centerIn: parent
                    text:                     "DONE"
                    font.pixelSize:           10
                    font.letterSpacing:       2
                    font.weight:              Font.Medium
                    color:                    ColorsModule.Colors.tertiary
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth:  true
            Layout.alignment:  Qt.AlignVCenter
            spacing:           20

            // Timer label with subtle divider
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text:               "TIMER"
                    font.pixelSize:     11
                    font.letterSpacing: 6
                    font.weight:        Font.Medium
                    color:              ColorsModule.Colors.primary
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    height: 1
                    color: ColorsModule.Colors.outline_variant
                }
            }

            // Time input fields with improved design
            RowLayout {
                spacing: 8
                enabled: !root.running && !root.finished

                // Hours field
                ColumnLayout {
                    spacing: 4

                    TextField {
                        id: hoursField
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 50
                        placeholderText: "HH"
                        inputMethodHints: Qt.ImhDigitsOnly
                        maximumLength: 2
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 22
                        font.weight: Font.Light
                        font.family: "monospace"
                        color: ColorsModule.Colors.on_surface
                        placeholderTextColor: ColorsModule.Colors.outline
                        selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 99 }

                        background: Rectangle {
                            radius: 10
                            color: hoursField.activeFocus
                                ? ColorsModule.Colors.surface_container_highest
                                : ColorsModule.Colors.surface_container_low
                            border.color: hoursField.activeFocus
                                ? ColorsModule.Colors.primary
                                : hoursField.text.length > 0
                                    ? ColorsModule.Colors.outline
                                    : ColorsModule.Colors.outline_variant
                            border.width: hoursField.activeFocus ? 2 : (hoursField.text.length > 0 ? 1.5 : 1)

                            Behavior on border.color { ColorAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: (event) => { hoursField.forceActiveFocus(); event.accepted = false }
                            cursorShape: Qt.IBeamCursor
                        }

                        onTextChanged: {
                            if (text.length === 2) minutesField.forceActiveFocus()
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "HH"
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                        color: hoursField.activeFocus || hoursField.text.length > 0
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.outline

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }

                Text {
                    text:             ":"
                    font.pixelSize:   28
                    font.weight:      Font.Thin
                    color:            ColorsModule.Colors.outline
                    Layout.alignment: Qt.AlignVCenter
                    bottomPadding:    14
                }

                // Minutes field
                ColumnLayout {
                    spacing: 4

                    TextField {
                        id: minutesField
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 50
                        placeholderText: "MM"
                        inputMethodHints: Qt.ImhDigitsOnly
                        maximumLength: 2
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 22
                        font.weight: Font.Light
                        font.family: "monospace"
                        color: ColorsModule.Colors.on_surface
                        placeholderTextColor: ColorsModule.Colors.outline
                        selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 59 }

                        background: Rectangle {
                            radius: 10
                            color: minutesField.activeFocus
                                ? ColorsModule.Colors.surface_container_highest
                                : ColorsModule.Colors.surface_container_low
                            border.color: minutesField.activeFocus
                                ? ColorsModule.Colors.primary
                                : minutesField.text.length > 0
                                    ? ColorsModule.Colors.outline
                                    : ColorsModule.Colors.outline_variant
                            border.width: minutesField.activeFocus ? 2 : (minutesField.text.length > 0 ? 1.5 : 1)

                            Behavior on border.color { ColorAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: (event) => { minutesField.forceActiveFocus(); event.accepted = false }
                            cursorShape: Qt.IBeamCursor
                        }

                        onTextChanged: {
                            if (text.length === 2) secondsField.forceActiveFocus()
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "MM"
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                        color: minutesField.activeFocus || minutesField.text.length > 0
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.outline

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }

                Text {
                    text:             ":"
                    font.pixelSize:   28
                    font.weight:      Font.Thin
                    color:            ColorsModule.Colors.outline
                    Layout.alignment: Qt.AlignVCenter
                    bottomPadding:    14
                }

                // Seconds field
                ColumnLayout {
                    spacing: 4

                    TextField {
                        id: secondsField
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 50
                        placeholderText: "SS"
                        inputMethodHints: Qt.ImhDigitsOnly
                        maximumLength: 2
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 22
                        font.weight: Font.Light
                        font.family: "monospace"
                        color: ColorsModule.Colors.on_surface
                        placeholderTextColor: ColorsModule.Colors.outline
                        selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 59 }

                        background: Rectangle {
                            radius: 10
                            color: secondsField.activeFocus
                                ? ColorsModule.Colors.surface_container_highest
                                : ColorsModule.Colors.surface_container_low
                            border.color: secondsField.activeFocus
                                ? ColorsModule.Colors.primary
                                : secondsField.text.length > 0
                                    ? ColorsModule.Colors.outline
                                    : ColorsModule.Colors.outline_variant
                            border.width: secondsField.activeFocus ? 2 : (secondsField.text.length > 0 ? 1.5 : 1)

                            Behavior on border.color { ColorAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: (event) => { secondsField.forceActiveFocus(); event.accepted = false }
                            cursorShape: Qt.IBeamCursor
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "SS"
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                        color: secondsField.activeFocus || secondsField.text.length > 0
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.outline

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }
            }

            // Notification message section with improved styling
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:               "NOTIFICATION"
                        font.pixelSize:     9
                        font.letterSpacing: 2
                        color:              ColorsModule.Colors.outline
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        height: 1
                        color: ColorsModule.Colors.outline_variant
                        opacity: 0.5
                    }
                }

                TextField {
                    id:               notifField
                    Layout.fillWidth: true
                    height:           42
                    placeholderText:  "Timer finished!"
                    font.pixelSize:   13
                    color:            ColorsModule.Colors.on_surface
                    placeholderTextColor: ColorsModule.Colors.outline
                    leftPadding:      14
                    selectByMouse:    true

                    background: Rectangle {
                        radius:       10
                        color:        notifField.activeFocus
                            ? ColorsModule.Colors.surface_container_high
                            : ColorsModule.Colors.surface_container_low
                        border.color: notifField.activeFocus
                            ? ColorsModule.Colors.secondary
                            : ColorsModule.Colors.outline_variant
                        border.width: notifField.activeFocus ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed:    (event) => { notifField.forceActiveFocus(); event.accepted = false }
                        cursorShape: Qt.IBeamCursor
                    }
                }
            }

            // Action buttons with improved design
            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                Rectangle {
                    Layout.fillWidth: true
                    height:  44
                    radius:  12

                    color: primaryBtn.containsMouse || root.running || root.remainingSeconds > 0
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.primary_container

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn:   parent
                        text: {
                            if (root.finished)             return "FINISHED"
                            if (root.running)              return "PAUSE"
                            if (root.remainingSeconds > 0) return "RESUME"
                            return "START"
                        }
                        font.pixelSize:     13
                        font.weight:        Font.Medium
                        font.letterSpacing: 1.5
                        color: root.running || root.remainingSeconds > 0
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.on_primary_container
                    }

                    MouseArea {
                        id:           primaryBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (root.finished) return
                            if (!root.running && root.remainingSeconds === 0) {
                                root.startTimer()
                            } else if (root.running) {
                                root.running = false
                            } else {
                                root.running = true
                            }
                        }
                    }
                }

                Rectangle {
                    width:        90
                    height:       44
                    radius:       12
                    color:        resetBtn.containsMouse
                        ? ColorsModule.Colors.surface_container_highest
                        : ColorsModule.Colors.surface_container_high
                    border.color: resetBtn.containsMouse
                        ? ColorsModule.Colors.outline
                        : ColorsModule.Colors.outline_variant
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn:   parent
                        text:               "RESET"
                        font.pixelSize:     12
                        font.weight:        Font.Medium
                        font.letterSpacing: 1
                        color:              ColorsModule.Colors.on_surface_variant
                    }

                    MouseArea {
                        id:           resetBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    root.resetTimer()
                    }
                }
            }
        }
    }
}