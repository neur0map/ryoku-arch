pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

/**
 * A live, plain-QML preview of the desktop clock widget for the Desktop Widgets
 * section, so the chosen face, date design, format and accent show at a glance
 * without leaning over the hub window to the wallpaper. It mirrors the live faces
 * in ryoku/shell/quickshell/shell/modules/desktop/clock; the accent follows your real
 * palette (Scheme singleton), the rest is bright ink as on the wallpaper.
 */
Item {
    id: preview

    property string design: "digital"
    property bool is24: true
    property bool seconds: false
    property string accentChoice: "palette"
    property bool dateShow: true
    property string dateDesign: "inline"

    readonly property color ink: "#f5f3ff"
    readonly property color inkSoft: "#d2d7ef"
    readonly property color inkDim: "#9aa3c8"
    readonly property color accent: preview.accentChoice === "brand" ? "#F25623"
        : preview.accentChoice === "mono" ? preview.ink : Scheme.accent

    property var now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: preview.now = new Date() }

    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    readonly property int h: now.getHours()
    readonly property int mins: now.getMinutes()
    readonly property int secs: now.getSeconds()
    readonly property int h12: (h % 12) === 0 ? 12 : (h % 12)
    readonly property string hh: preview.is24 ? pad2(h) : String(h12)
    readonly property string mm: pad2(mins)
    readonly property string ss: pad2(secs)
    readonly property string ampm: h < 12 ? "AM" : "PM"

    readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var weekdaysShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property int dow: now.getDay()
    readonly property int dom: now.getDate()
    readonly property int monIdx: now.getMonth()

    Column {
        anchors.centerIn: parent
        spacing: 14

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: preview.faceFor()
        }
        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: preview.dateShow
            visible: preview.dateShow
            sourceComponent: preview.dateShow ? preview.dateFor() : null
        }
    }

    function faceFor() {
        switch (preview.design) {
        case "minimal": return minimalC;
        case "analog":  return analogC;
        case "flip":    return flipC;
        case "rings":   return ringsC;
        default:        return digitalC;
        }
    }
    function dateFor() {
        switch (preview.dateDesign) {
        case "badge":   return badgeC;
        case "stacked": return stackedC;
        default:        return inlineC;
        }
    }

    // --- faces -------------------------------------------------------------
    Component {
        id: digitalC
        Row {
            spacing: preview.seconds || !preview.is24 ? 10 : 0
            Row {
                spacing: 0
                Text { text: preview.hh; color: preview.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 56; font.weight: Font.Bold }
                Text {
                    text: ":"; color: preview.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 56; font.weight: Font.Bold
                    SequentialAnimation on opacity { loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.3; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.3; to: 1; duration: 620; easing.type: Easing.InOutSine } }
                }
                Text { text: preview.mm; color: preview.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 56; font.weight: Font.Bold }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text { visible: preview.seconds; text: preview.ss; color: preview.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17; font.weight: Font.DemiBold }
                Text { visible: !preview.is24; text: preview.ampm; color: preview.inkDim; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
        }
    }

    Component {
        id: minimalC
        Column {
            spacing: 8
            Text { id: mt; text: preview.hh + ":" + preview.mm; color: preview.ink; font.family: "Inter"; font.pixelSize: 54; font.weight: Font.Light; font.letterSpacing: 2 }
            Rectangle { width: mt.implicitWidth * 0.34; height: 3; radius: Theme.radius; color: preview.accent }
            Text {
                visible: preview.seconds || !preview.is24
                text: (preview.seconds ? preview.ss : "") + (preview.seconds && !preview.is24 ? "  " : "") + (!preview.is24 ? preview.ampm.toLowerCase() : "")
                color: preview.inkDim; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium; font.letterSpacing: 3
            }
        }
    }

    Component {
        id: analogC
        Item {
            implicitWidth: 132; implicitHeight: 132
            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14) }
            Repeater {
                model: 12
                Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * 30
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 6
                        width: parent.index % 3 === 0 ? 3 : 2; height: parent.index % 3 === 0 ? 10 : 6
                        radius: width / 2; color: parent.index % 3 === 0 ? preview.ink : preview.inkDim
                    }
                }
            }
            Rectangle { x: (parent.width - width) / 2; y: parent.height / 2 - height; width: 5; height: parent.height * 0.28; radius: Theme.radius; color: preview.ink; antialiasing: true; transformOrigin: Item.Bottom; rotation: (preview.h % 12 + preview.mins / 60) * 30 }
            Rectangle { x: (parent.width - width) / 2; y: parent.height / 2 - height; width: 4; height: parent.height * 0.40; radius: Theme.radius; color: preview.ink; antialiasing: true; transformOrigin: Item.Bottom; rotation: (preview.mins + preview.secs / 60) * 6 }
            Rectangle { x: (parent.width - width) / 2; y: parent.height / 2 - height; width: 2; height: parent.height * 0.44; radius: Theme.radius; color: preview.accent; antialiasing: true; transformOrigin: Item.Bottom; rotation: preview.secs * 6 }
            Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 4.5; color: preview.accent; border.width: 1.5; border.color: preview.ink }
        }
    }

    Component {
        id: flipC
        Row {
            spacing: 5
            Repeater {
                model: [preview.is24 ? preview.hh.charAt(0) : preview.pad2(preview.h12).charAt(0),
                        preview.is24 ? preview.hh.charAt(1) : preview.pad2(preview.h12).charAt(1),
                        ":", preview.mm.charAt(0), preview.mm.charAt(1)]
                Item {
                    required property var modelData
                    readonly property bool colon: modelData === ":"
                    width: colon ? 18 : 46
                    height: 64
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        visible: !parent.colon
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Qt.rgba(0, 0, 0, 0.55)
                        border.width: 1
                        border.color: Qt.rgba(preview.accent.r, preview.accent.g, preview.accent.b, 0.24)
                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 1; color: Qt.rgba(0, 0, 0, 0.4) }
                    }
                    Text { anchors.centerIn: parent; text: parent.modelData; color: parent.colon ? preview.accent : preview.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: parent.colon ? 34 : 40; font.weight: Font.Bold }
                }
            }
        }
    }

    Component {
        id: ringsC
        Item {
            implicitWidth: 138; implicitHeight: 138
            Canvas {
                id: rc
                anchors.fill: parent
                readonly property var key: [preview.now, preview.accent]
                onKeyChanged: requestPaint()
                function css(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"; }
                onPaint: {
                    var ctx = getContext("2d"); var w = width; ctx.reset(); ctx.clearRect(0, 0, w, w);
                    var cx = w / 2, lw = w * 0.05, gap = lw * 1.75, r0 = w / 2 - lw * 0.7 - 2;
                    var radii = [r0 - 2 * gap, r0 - gap, r0];
                    var fr = [((preview.h % 12) + preview.mins / 60) / 12, (preview.mins + preview.secs / 60) / 60, preview.secs / 60];
                    var tints = preview.accentChoice === "palette"
                        ? [Scheme.colorAt(0.2), Scheme.colorAt(0.5), Scheme.colorAt(0.85)]
                        : [preview.accent, preview.accent, preview.accent];
                    for (var i = 0; i < 3; i++) {
                        ctx.beginPath(); ctx.lineWidth = lw; ctx.lineCap = "butt"; ctx.strokeStyle = rc.css(preview.ink, 0.12);
                        ctx.arc(cx, cx, radii[i], 0, 2 * Math.PI, false); ctx.stroke();
                        if (fr[i] > 0.0001) {
                            ctx.beginPath(); ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.strokeStyle = rc.css(tints[i], 1);
                            ctx.arc(cx, cx, radii[i], -Math.PI / 2, -Math.PI / 2 + fr[i] * 2 * Math.PI, false); ctx.stroke();
                        }
                    }
                }
            }
            Text { anchors.centerIn: parent; text: preview.hh + ":" + preview.mm; color: preview.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; font.weight: Font.Bold }
        }
    }

    // --- date designs ------------------------------------------------------
    Component {
        id: inlineC
        Row {
            spacing: 8
            Text { text: preview.weekdays[preview.dow]; color: preview.accent; font.family: "Inter"; font.pixelSize: 18; font.weight: Font.DemiBold }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "\u00b7"; color: preview.inkDim; font.family: "Inter"; font.pixelSize: 18; font.weight: Font.Bold }
            Text { text: preview.months[preview.monIdx] + " " + preview.dom; color: preview.inkSoft; font.family: "Inter"; font.pixelSize: 18; font.weight: Font.Medium }
        }
    }
    Component {
        id: badgeC
        Rectangle {
            implicitWidth: bi.implicitWidth + 24; implicitHeight: bi.implicitHeight + 14; radius: Theme.radius
            color: Qt.rgba(preview.accent.r, preview.accent.g, preview.accent.b, 0.16)
            border.width: 1; border.color: Qt.rgba(preview.accent.r, preview.accent.g, preview.accent.b, 0.42)
            Row {
                id: bi
                anchors.centerIn: parent; spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: preview.dom; color: preview.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 34; font.weight: Font.Bold }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Text { text: preview.weekdaysShort[preview.dow].toUpperCase(); color: preview.accent; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 2 }
                    Text { text: preview.months[preview.monIdx]; color: preview.inkSoft; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium }
                }
            }
        }
    }
    Component {
        id: stackedC
        Row {
            spacing: 12
            Text { anchors.verticalCenter: parent.verticalCenter; text: preview.dom; color: preview.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 44; font.weight: Font.Bold }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Text { text: preview.weekdays[preview.dow]; color: preview.accent; font.family: "Inter"; font.pixelSize: 19; font.weight: Font.DemiBold }
                Text { text: preview.months[preview.monIdx] + " " + preview.now.getFullYear(); color: preview.inkDim; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.Medium }
            }
        }
    }
}
