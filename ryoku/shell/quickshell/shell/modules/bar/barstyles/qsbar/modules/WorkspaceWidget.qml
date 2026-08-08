import Quickshell.Hyprland
import QtQuick

Item {
    id: wsWidget
    required property var root

    implicitWidth: wsRow.implicitWidth
    implicitHeight: 28

    // The focused workspace's id ONLY when it's a real (positive) workspace beyond
    // the persist range — else 0. An int signals on value change only, so switching
    // between in-range workspaces does NOT renotify → workspaceList stays identical
    // → the Repeater model is stable → the per-delegate width/colour Behaviors keep
    // animating instead of the whole model rebuilding (B2). `id > n` (n≥5) also
    // excludes negative special/scratchpad ids (B3).
    readonly property int extraWs: {
        if (root.workspaceMode === "active") return 0
        var n = root.workspaceMode === "5" ? 5 : 10
        var f = Hyprland.focusedWorkspace
        return (f && f.id > n) ? f.id : 0
    }

    readonly property var workspaceList: {
        if (root.workspaceMode === "active") {
            var ids = {}
            var ws = Hyprland.workspaces.values
            for (var i = 0; i < ws.length; i++) if (ws[i].id > 0) ids[ws[i].id] = true   // F13: skip special (negative-id) workspaces
            if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ids[Hyprland.focusedWorkspace.id] = true
            return Object.keys(ids).map(Number).sort(function(a, b) { return a - b })
        }
        var n = root.workspaceMode === "5" ? 5 : 10
        var list = []; for (var j = 1; j <= n; j++) list.push(j)
        if (extraWs > 0) list.push(extraWs)   // focused-beyond-range, stable per id
        return list
    }

    Rectangle {
        x: -root.wsPillPad; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(wsRow.width) + 2 * root.wsPillPad
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    // right-click anywhere opens the workspace panel
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.workspaceVisible = !root.workspaceVisible
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: wsWidget.workspaceList

            delegate: Item {
                id: wsCell
                required property int modelData
                readonly property int wsId: modelData

                // hover feedback works in every style (the old code scaled the
                // default-only `dot`, invisible in numbers/magic)
                Behavior on scale { NumberAnimation { duration: 120 } }

                readonly property bool isFocused: Hyprland.focusedWorkspace !== null
                                               && Hyprland.focusedWorkspace.id === wsId

                readonly property bool isOccupied: {
                    var ws = Hyprland.workspaces.values
                    for (var i = 0; i < ws.length; i++)
                        if (ws[i].id === wsId) return !isFocused
                    return false
                }

                readonly property bool isEmpty: !isFocused && !isOccupied

                implicitWidth: root.workspaceStyle === "numbers" ? 22
                             : root.workspaceStyle === "magic"   ? (isFocused ? 20 : 18)
                             : (isFocused ? 32 : 16)
                implicitHeight: 28

                Behavior on implicitWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // ── DEFAULT style: glow + dot ──
                // glow — alle states, nur opacity variiert
                Rectangle {
                    visible: root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  isFocused ? 34 : 16
                    height: isFocused ? 16 : 16
                    radius: isFocused ?  8 :  8
                    color: isFocused
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                        : isOccupied
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.06)

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // pill / kreis
                Rectangle {
                    id: dot
                    visible: root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  isFocused  ? 26 : 8
                    height: 8
                    radius: 4
                    color:  isFocused
                        ? root.seal
                        : isOccupied
                        ? root.seal
                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // ── NUMBERS style: a digit on a rounded badge (radius follows
                //    the bar radius switch: round/12 ⇄ 5) ──
                Rectangle {
                    visible: root.workspaceStyle === "numbers"
                    anchors.centerIn: parent
                    width:  20
                    height: 20
                    radius: root.styleRadiusSmall ? 5 : height / 2
                    color: isFocused  ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.30)
                         : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                                      : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.04)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: wsId
                        // focused = the only BRIGHT digit (lightened seal + bold + bigger);
                        // others dimmed so the active workspace is unmistakable
                        color: isFocused  ? Qt.lighter(root.seal, 1.3)
                             : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.5)
                                          : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.28)
                        font.family: root.mono
                        font.pixelSize: isFocused ? 13 : 12
                        font.weight: isFocused ? Font.Bold : Font.Normal
                    }
                }

                // ── MAGIC style: the 3 ORIGINAL sparkle glyphs (filled / hollow / dot),
                //    all forced into ONE font (Adwaita Mono has all three) so they share
                //    a metric → no cross-font fallback misalignment ──
                Text {
                    visible: root.workspaceStyle === "magic"
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: isFocused ? 0 : 1   // active lifted vs occupied/empty
                    text: isFocused  ? String.fromCodePoint(0x2726)    // ✦ filled four-point star (active)
                         : isOccupied ? String.fromCodePoint(0x2727)    // ✧ hollow four-point star (occupied)
                                      : String.fromCodePoint(0x00B7)    // · middle dot (empty)
                    color: isFocused  ? root.seal
                         : isOccupied ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.7)
                                      : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3)
                    font.family: "Adwaita Mono"   // all 3 sparkle glyphs live here → one consistent metric
                    font.pixelSize: isFocused ? 22 : 18
                    renderType: Text.NativeRendering   // crisp hinted raster (default QtRendering softens small symbols)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.gotoWorkspace(wsId)
                    onEntered: wsCell.scale = 1.15
                    onExited:  wsCell.scale = 1.0
                }
            }
        }
    }

}
