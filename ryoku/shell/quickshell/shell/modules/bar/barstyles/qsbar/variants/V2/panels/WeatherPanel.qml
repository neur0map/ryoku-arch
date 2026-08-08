import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: wxPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-weather"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property string temp: ""
    property string feels: ""
    property string desc: ""
    property string location: ""
    property string humidity: ""
    property string wind: ""
    property var    forecastDays: []
    property bool   refreshing: false

    function refresh() {
        if (wxData.running) return
        refreshing = true
        wxData.running = true
    }

    // data is fetched in °C / km·h; convert on display per root.weatherImperial
    function tConv(c) {
        var n = parseFloat(c); if (isNaN(n)) return c
        return root.weatherImperial ? String(Math.round(n * 9 / 5 + 32)) : String(Math.round(n))
    }
    function wConv(kmh) {
        var n = parseFloat(kmh); if (isNaN(n)) return kmh
        return root.weatherImperial ? (Math.round(n * 0.621371) + " mph") : (kmh + " km/h")
    }
    function glyphForCode(code) {
        var n = parseInt(code) || 0
        if (n === 113) return String.fromCodePoint(0xe30d)
        if (n === 116) return String.fromCodePoint(0xe302)
        if (n === 119 || n === 122) return String.fromCodePoint(0xe33d)
        if (n === 143 || n === 248 || n === 260) return String.fromCodePoint(0xe313)
        if (n === 176 || n === 263 || n === 266 || n === 293 || n === 296 || n === 353) return String.fromCodePoint(0xe308)
        if (n === 179 || n === 227 || n === 230 || n === 323 || n === 326 || n === 368) return String.fromCodePoint(0xe30a)
        if (n === 182 || n === 185 || n === 281 || n === 284 || n === 311 || n === 314 || n === 317 || n === 320 || n === 350 || n === 362 || n === 365 || n === 374 || n === 377) return String.fromCodePoint(0xe3ad)
        if (n === 200 || n === 386 || n === 389 || n === 392 || n === 395) return String.fromCodePoint(0xe31d)
        if (n === 299 || n === 302 || n === 305 || n === 308 || n === 356 || n === 359) return String.fromCodePoint(0xe318)
        if (n === 329 || n === 332 || n === 335 || n === 338 || n === 371) return String.fromCodePoint(0xe31a)
        return String.fromCodePoint(0xe33d)
    }
    function dayLabel(dateStr, index) {
        if (index === 0) return "Today"
        if (index === 1) return "Tomorrow"
        var d = new Date(dateStr + "T00:00:00")
        if (isNaN(d.getTime())) return dateStr
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()]
    }
    function dayRange(day) {
        var unit = root.weatherImperial ? "°F" : "°C"
        return tConv(day.min) + "°/" + tConv(day.max) + unit
    }
    function chanceOfRain(day) {
        var hourly = day && day.hourly ? day.hourly : []
        var maxRain = 0
        for (var i = 0; i < hourly.length; i++) {
            var rain = parseFloat(hourly[i].chanceofrain)
            if (!isNaN(rain) && rain > maxRain) maxRain = rain
        }
        return maxRain
    }
    function forecastCode(day) {
        var hourly = day && day.hourly ? day.hourly : []
        var noon = hourly.length > 4 ? hourly[4] : (hourly.length > 0 ? hourly[0] : null)
        return noon ? (noon.weatherCode || "") : ""
    }
    function parseReport(raw) {
        var d = JSON.parse(raw)
        var current = d.current_condition && d.current_condition[0] ? d.current_condition[0] : null
        var area = d.nearest_area && d.nearest_area[0] ? d.nearest_area[0] : null
        if (!current) return false

        wxPanel.temp = current.temp_C || ""
        wxPanel.feels = current.FeelsLikeC || ""
        wxPanel.desc = current.weatherDesc && current.weatherDesc[0] ? current.weatherDesc[0].value || "" : ""
        wxPanel.humidity = current.humidity || ""
        wxPanel.wind = current.windspeedKmph || ""
        wxPanel.location = area && area.areaName && area.areaName[0] ? area.areaName[0].value || "" : ""

        var days = []
        var reportDays = d.weather || []
        for (var i = 0; i < reportDays.length && i < 3; i++) {
            var day = reportDays[i]
            days.push({
                date: day.date || "",
                min: day.mintempC || "",
                max: day.maxtempC || "",
                code: forecastCode(day),
                desc: "",
                rain: chanceOfRain(day)
            })
        }
        wxPanel.forecastDays = days
        return true
    }

    property real reveal: root.weatherVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.weatherVisible ? 160 : 120
            easing.type: root.weatherVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.weatherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.weatherVisible = false }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: wxPanel.root
            ownerActive: wxPanel.root.weatherVisible
            targetX: wxPanel.root.weatherBarX
            reveal: wxPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.weatherBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - wxPanel.reveal)
            : (barBottom + gap) - 2 * (1 - wxPanel.reveal)
        opacity: wxPanel.reveal
        focus: root.weatherVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.weatherVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Weather"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.weatherVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Item {
                width: parent.width
                height: 36
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: wxPanel.temp !== "" ? wxPanel.tConv(wxPanel.temp) + "°" + (root.weatherImperial ? "F" : "C") : "—"
                    color: root.seal; font.family: root.mono; font.pixelSize: 26; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: wxPanel.desc
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    width: parent.width * 0.55; wrapMode: Text.WordWrap
                }
            }

            Column {
                width: parent.width
                spacing: 4
                Row {
                    width: parent.width
                    visible: wxPanel.location !== ""
                    UiText { text: "Location"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: wxPanel.location; color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.6; elide: Text.ElideRight }
                }
                Row {
                    width: parent.width
                    visible: wxPanel.feels !== ""
                    UiText { text: "Feels like"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: wxPanel.tConv(wxPanel.feels) + "°" + (root.weatherImperial ? "F" : "C"); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: wxPanel.humidity !== ""
                    UiText { text: "Humidity"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: wxPanel.humidity + "%"; color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    visible: wxPanel.wind !== ""
                    UiText { text: "Wind"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: wxPanel.wConv(wxPanel.wind); color: root.ink; font.family: root.mono; font.pixelSize: 11 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Column {
                width: parent.width
                spacing: 5
                visible: wxPanel.forecastDays.length > 0

                UiText {
                    text: "3-DAY FORECAST"
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }

                Repeater {
                    model: wxPanel.forecastDays
                    delegate: Item {
                        width: col.width
                        height: 24
                        property var day: modelData

                        UiText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 66
                            text: wxPanel.dayLabel(day.date || "", index)
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 76
                            anchors.verticalCenter: parent.verticalCenter
                            text: wxPanel.glyphForCode(day.code)
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 14
                        }
                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: 106
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76
                            text: wxPanel.dayRange(day)
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76
                            text: (day.rain !== undefined ? Math.round(day.rain) + "% rain" : "")
                            color: root.sumiHi
                            font.family: root.mono
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: wxPanel.forecastDays.length > 0 }

            Row {
                width: parent.width
                height: 28
                spacing: 6
                // Refresh (primary)
                Rectangle {
                    width: root.evenW((parent.width - parent.spacing) / 2)
                    height: 28; radius: root.panelButtonRadius
                    color: wxPanel.refreshing ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.45)
                           : wxBtnMa.containsMouse ? root.fillPrimaryHover : root.seal
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: wxPanel.refreshing ? "Refreshing…" : "Refresh"
                        color: root.paper; font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: wxBtnMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: !wxPanel.refreshing
                        onClicked: wxPanel.refresh()
                    }
                }
                // Unit toggle (secondary): shows the unit you'd switch TO
                Rectangle {
                    width: root.evenW((parent.width - parent.spacing) / 2)
                    height: 28; radius: root.panelButtonRadius
                    color: unitMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: unitMa.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: root.weatherImperial ? "metric" : "imperial"
                        color: unitMa.containsMouse ? root.seal : root.ink
                        font.family: root.mono; font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: unitMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.weatherImperial = !root.weatherImperial
                    }
                }
            }
        }
    }

    Process {
        id: wxData
        command: ["curl", "-fs", "--max-time", "5", "https://wttr.in?format=j1"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var txt = String(this.text || "").trim()
                if (txt === "") return
                try {
                    wxPanel.parseReport(txt)
                } catch (e) {
                    // Keep the last valid panel data on transient weather failures.
                }
            }
        }
        onExited: wxPanel.refreshing = false
    }

    onVisibleChanged: { if (visible && wxPanel.temp === "") wxPanel.refresh() }
}
