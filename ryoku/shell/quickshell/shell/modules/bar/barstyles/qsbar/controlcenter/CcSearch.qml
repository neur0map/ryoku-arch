import QtQuick
import "../modules"
import "SearchEngine.js" as SearchEngine

// Predictive settings search. Faithful port of Shibumi's PredictiveSearchInput
// wearing qsbar's dark skin: a focusable field with the CTRL K hint, ghost-text
// completion, and a suggestions popup that RESERVES its height (grows this
// item's implicitHeight) so it never overlaps the content below it. Keyboard:
// Up/Down cycle, Tab/Enter/Right accept the active suggestion, and a staged
// Escape closes suggestions → clears text → blurs (a further Escape then bubbles
// to the card and closes the panel). Ranking lives in SearchEngine.js.
Item {
    id: search
    property var root
    property var entries: []               // the settings index (from ControlCenter)
    property alias text: input.text
    property int suggestionLimit: 5
    property int activeIndex: -1           // -1 = no explicit pick (index 0 is active)
    property bool suppressed: true         // suppress the popup until focused + typing

    signal accepted(var entry)             // wired by ControlCenter → cc.open(entry.route)

    readonly property int inputH: 40
    readonly property int suggestRowH: 34
    readonly property var suggestions:
        (!suppressed && input.text.trim() !== "" && !!entries && entries.length > 0)
            ? SearchEngine.ranked(entries, input.text, suggestionLimit) : []
    readonly property bool suggestionsVisible: suggestions.length > 0
    readonly property int effectiveIndex: activeIndex >= 0 ? activeIndex : 0
    readonly property var activeSuggestion:
        suggestions.length > 0 ? suggestions[search.effectiveIndex] : null
    readonly property string ghost: SearchEngine.ghostText(input.text, search.activeSuggestion)
    readonly property real popupBodyH: suggestionsVisible ? suggestions.length * suggestRowH + 2 : 0
    readonly property real reservedH: suggestionsVisible ? 6 + popupBodyH : 0

    implicitHeight: inputH + reservedH
    z: suggestionsVisible ? 80 : 0

    function focusInput() { search.suppressed = false; input.forceActiveFocus() }
    function clear() { input.text = ""; search.activeIndex = -1; search.suppressed = true }
    function blur() { search.activeIndex = -1; search.suppressed = true; input.focus = false }

    function moveSuggestion(offset) {
        if (search.suggestions.length === 0) return
        var base = search.effectiveIndex
        search.activeIndex = (base + offset + search.suggestions.length) % search.suggestions.length
    }
    function acceptSuggestion(index) {
        if (search.suggestions.length === 0) return false
        var i = (index >= 0 && index < search.suggestions.length) ? index : 0
        var entry = search.suggestions[i]
        if (!entry) return false
        search.accepted(entry)
        search.clear()
        return true
    }
    // Staged Escape: hide suggestions first, then clear + blur on the next press.
    function handleEscape() {
        if (search.suggestionsVisible) { search.activeIndex = -1; search.suppressed = true; return }
        input.text = ""
        search.blur()
    }

    // ── the input field (fixed height, pinned to the top of the reserved area) ──
    Rectangle {
        id: field
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: search.inputH
        radius: search.root ? search.root.tileRadius : 6
        color: search.root ? search.root.fillIdle : "transparent"
        border.width: 1
        border.color: input.activeFocus ? (search.root ? search.root.seal : "#888888")
                                        : (search.root ? search.root.sep : "#333333")
        Behavior on border.color { ColorAnimation { duration: 120 } }

        IconText {
            id: glass
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            color: search.root ? search.root.sumi : "#888888"
            opacity: input.activeFocus ? 0.9 : 0.55
            font.pixelSize: 16
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.IBeamCursor
            onClicked: search.focusInput()
        }
        // placeholder — shown only when empty
        UiText {
            anchors.left: input.left; anchors.right: input.right
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: "Search settings, options, or routes\u2026"
            color: search.root ? search.root.sumi : "#888888"
            opacity: 0.7
            elide: Text.ElideRight
            font.family: search.root ? search.root.mono : "monospace"
            font.pixelSize: 12
        }
        // ghost completion — drawn under the caret; the real text overlays it
        Text {
            anchors.left: input.left; anchors.right: input.right
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text !== "" && search.ghost !== ""
            text: search.ghost
            color: search.root ? search.root.sumi : "#888888"
            opacity: 0.45
            elide: Text.ElideRight
            font.family: search.root ? search.root.mono : "monospace"
            font.pixelSize: 12
        }
        TextInput {
            id: input
            anchors.left: glass.right; anchors.leftMargin: 8
            anchors.right: trailing.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: search.root ? search.root.ink : "#cccccc"
            selectionColor: search.root ? search.root.fillActive : "#444444"
            selectedTextColor: search.root ? search.root.ink : "#ffffff"
            selectByMouse: true
            clip: true
            font.family: search.root ? search.root.mono : "monospace"
            font.pixelSize: 12

            onTextEdited: { search.suppressed = false; search.activeIndex = -1 }
            onActiveFocusChanged: { search.activeIndex = -1; search.suppressed = !activeFocus }

            Keys.onPressed: function(e) {
                if (e.key === Qt.Key_Escape) { search.handleEscape(); e.accepted = true; return }
                if (search.suggestionsVisible && (e.key === Qt.Key_Down || e.key === Qt.Key_Up)) {
                    search.moveSuggestion(e.key === Qt.Key_Down ? 1 : -1)
                    e.accepted = true
                    return
                }
                var accepts = e.key === Qt.Key_Tab
                    || e.key === Qt.Key_Return || e.key === Qt.Key_Enter
                    || (e.key === Qt.Key_Right && input.cursorPosition === input.length)
                if (search.suggestionsVisible && accepts) {
                    search.acceptSuggestion(search.activeIndex)
                    e.accepted = true
                }
            }
        }
        // trailing slot: CTRL K hint when empty, a clear button once typing
        Item {
            id: trailing
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(hint.width, clearBtn.implicitWidth)
            height: parent.height

            Rectangle {
                id: hint
                anchors.centerIn: parent
                visible: input.text === ""
                width: kb.implicitWidth + 12; height: 18
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: search.root ? search.root.sep : "#333333"
                UiText {
                    id: kb
                    anchors.centerIn: parent
                    text: "CTRL K"
                    color: search.root ? search.root.sumi : "#888888"
                    font.family: search.root ? search.root.mono : "monospace"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
            }
            IconText {
                id: clearBtn
                anchors.centerIn: parent
                visible: input.text !== ""
                text: "close"
                color: search.root ? search.root.sumi : "#888888"
                opacity: clearHover.containsMouse ? 0.9 : 0.5
                font.pixelSize: 15
                MouseArea {
                    id: clearHover
                    anchors.fill: parent; anchors.margins: -7
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { search.clear(); input.forceActiveFocus() }
                }
            }
        }
    }

    // ── suggestions popup — lives inside the reserved area, never overlaps below ──
    Rectangle {
        id: popup
        visible: search.suggestionsVisible
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: field.bottom; anchors.topMargin: 6
        height: search.popupBodyH
        radius: search.root ? search.root.tileRadius : 6
        // opaque surface: the card bg is translucent, so force full alpha here
        color: search.root ? Qt.rgba(search.root.paper.r, search.root.paper.g, search.root.paper.b, 1) : "#181616"
        border.width: 1
        border.color: search.root ? search.root.sep : "#333333"
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 1

            Repeater {
                id: rep
                model: search.suggestions

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: parent ? parent.width : 0
                    height: search.suggestRowH
                    readonly property bool active: row.index === search.effectiveIndex || pointer.containsMouse
                    color: row.active ? (search.root ? search.root.fillHover : "transparent") : "transparent"

                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: 1
                        visible: row.index < rep.count - 1
                        color: search.root ? search.root.sep : "#333333"
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 11; anchors.rightMargin: 9
                        spacing: 8

                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - meta.implicitWidth - parent.spacing
                            text: String(row.modelData.name || row.modelData.id || "")
                            color: row.active ? (search.root ? search.root.ink : "#ffffff")
                                              : (search.root ? search.root.sumiHi : "#cccccc")
                            elide: Text.ElideRight
                            font.family: search.root ? search.root.mono : "monospace"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        UiText {
                            id: meta
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(row.modelData.category || "").toUpperCase() + " \u00b7 TAB"
                            color: search.root ? search.root.sumi : "#888888"
                            opacity: 0.6
                            font.family: search.root ? search.root.mono : "monospace"
                            font.pixelSize: 9
                            font.letterSpacing: 0.4
                        }
                    }

                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: search.activeIndex = row.index
                        onClicked: search.acceptSuggestion(row.index)
                    }
                }
            }
        }
    }
}
