import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AI usage panel: shows Claude Code, OpenAI Codex, and OpenCode usage and lets the user
// switch which tool's icon the bar pill displays (root.aiTool). Opened from the
// combined AI pill (ClaudeWidget). Reads the same caches the bar widget reads.
PanelWindow {
    id: aiPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-ai-usage"

    readonly property int barBottom: 35
    readonly property int gap: 8

    // ── usage data: rendered from root.ai* — the single shared parse in Theme.qml
    //    that the bar pill uses too, so the two views can never drift apart. ──
    readonly property int    clPct5h:     root.aiClPct5h
    readonly property int    clPct7d:     root.aiClPct7d
    readonly property int    clReset5hTs: root.aiClReset5hTs
    readonly property int    clReset7dTs: root.aiClReset7dTs
    readonly property string clTokens:    root.aiClTokens
    readonly property string clRate:      root.aiClRate
    readonly property int    clToday:     root.aiClToday
    readonly property bool   clFresh:     root.aiClFresh
    readonly property bool   clHas:       root.aiClHas

    readonly property int    cxPct5h:     root.aiCxPct5h
    readonly property int    cxPct7d:     root.aiCxPct7d
    readonly property int    cxReset5hTs: root.aiCxReset5hTs
    readonly property int    cxReset7dTs: root.aiCxReset7dTs
    readonly property string cxPlan:      root.aiCxPlan
    readonly property string cxTokens:    root.aiCxTokens
    readonly property string cxRate:      root.aiCxRate
    readonly property int    cxToday:     root.aiCxToday
    readonly property bool   cxFresh:     root.aiCxFresh
    readonly property bool   cxHas:       root.aiCxHas
    readonly property var    cxWindows:   root.aiCxWindows || []
    readonly property string cxLimitStatus: root.aiCxLimitStatus
    readonly property string cxLimitReachedType: root.aiCxLimitReachedType
    readonly property var    cxWin0:      cxWindows.length > 0 ? cxWindows[0] : null
    readonly property var    cxWin1:      cxWindows.length > 1 ? cxWindows[1] : null
    readonly property bool   cxHasGeneral5h: {
        for (var i = 0; i < cxWindows.length; i++) {
            if ((cxWindows[i] || {}).minutes === 300) return true
        }
        return false
    }

    readonly property int    ocPct5h:     root.aiOcPct5h
    readonly property int    ocPct7d:     root.aiOcPct7d
    readonly property string ocPlan:      root.aiOcPlan
    readonly property string ocTokens:    root.aiOcTokens
    readonly property string ocRate:      root.aiOcRate
    readonly property string ocModel:     root.aiOcModel
    readonly property int    ocToday:     root.aiOcToday
    readonly property bool   ocFresh:     root.aiOcFresh
    readonly property bool   ocHas:       root.aiOcHas
    readonly property var    ocModels:    root.aiOcModels
    readonly property bool   showClaude:  root.aiTool === "claude"
    readonly property bool   showCodex:   root.aiTool === "codex"
    readonly property bool   showOpenCode: root.aiTool === "opencode"

    property real reveal: root.aiUsageVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.aiUsageVisible ? 160 : 120
            easing.type: root.aiUsageVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.aiUsageVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.aiUsageVisible = false
    }

    // ── reusable label · bar · % row ──
    component UsageRow: Item {
        property string label: ""
        property int pct: 0
        property bool dim: false
        width: parent ? parent.width : 0
        height: 16
        UiText {
            id: rowLbl
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: label; color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.letterSpacing: 1
        }
        UiText {
            id: rowVal
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: pct + "%"
            color: dim ? aiPanel.root.sumi : aiPanel.root.seal
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.weight: Font.Medium
        }
        Rectangle {
            anchors.left: rowLbl.right; anchors.leftMargin: 8
            anchors.right: rowVal.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 8; radius: 4
            color: Qt.rgba(aiPanel.root.seal.r, aiPanel.root.seal.g, aiPanel.root.seal.b, 0.15)
            Rectangle {
                width: parent.width * Math.min(100, parent ? pct : 0) / 100
                height: parent.height; radius: 4
                color: pct >= 90 ? aiPanel.root.sealRaw : aiPanel.root.seal
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
    }

    // ── reusable key/value detail row ──
    component DetailRow: Row {
        property string k: ""
        property string v: ""
        width: parent ? parent.width : 0
        UiText {
            text: k; color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: parent.width * 0.45
        }
        UiText {
            text: v; color: aiPanel.root.ink
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: parent.width * 0.55; horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    // ── compact OpenCode per-model usage row ──
    component ModelUsageRow: Item {
        property string name: ""
        property string totalLabel: ""
        property string inputLabel: ""
        property string outputLabel: ""
        property string reasoningLabel: ""
        property string cacheReadLabel: ""
        property string cacheWriteLabel: ""
        property string todayLabel: ""
        property int pct: 0

        width: parent ? parent.width : 0
        height: 42

        UiText {
            id: modelName
            anchors.left: parent.left; anchors.top: parent.top
            width: parent.width * 0.68
            text: name
            elide: Text.ElideRight
            color: aiPanel.root.ink
            font.family: aiPanel.root.mono; font.pixelSize: 10; font.weight: Font.Medium
        }
        UiText {
            anchors.right: parent.right; anchors.top: parent.top
            text: totalLabel
            color: aiPanel.root.seal
            font.family: aiPanel.root.mono; font.pixelSize: 10; font.weight: Font.Medium
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: modelName.bottom; anchors.topMargin: 5
            height: 6; radius: 3
            color: Qt.rgba(aiPanel.root.seal.r, aiPanel.root.seal.g, aiPanel.root.seal.b, 0.14)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, pct)) / 100
                height: parent.height; radius: 3
                color: aiPanel.root.seal
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
        UiText {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            text: "I " + inputLabel + "  O " + outputLabel
                + (reasoningLabel !== "0" ? "  R " + reasoningLabel : "")
                + (cacheReadLabel !== "0" ? "  CR " + cacheReadLabel : "")
                + (cacheWriteLabel !== "0" ? "  CW " + cacheWriteLabel : "")
                + (todayLabel !== "0" ? "  today " + todayLabel : "")
            elide: Text.ElideRight
            color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 9
        }
    }

    Rectangle {
        id: card
        width: 360
        height: Math.min(col.implicitHeight + 24, parent.height - 2 * (barBottom + gap))
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.aiBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: aiPanel.reveal
        focus: root.aiUsageVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.aiUsageVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: scroller.width
                spacing: 8

                // ── header ──
                Item {
                    width: parent.width
                    height: 24
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "AI USAGE"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: closeMa.containsMouse ? root.seal : root.sumi
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 120 } }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.aiUsageVisible = false
                        }
                    }
                }

                // ── segmented switch: which tool the bar shows ──
                Row {
                    width: parent.width
                    height: 28
                    spacing: 6
                    Repeater {
                        model: [ { id: "claude", label: "Claude" }, { id: "codex", label: "Codex" }, { id: "opencode", label: "OpenCode" } ]
                        Rectangle {
                            required property var modelData
                            width: root.evenW((parent.width - 12) / 3)
                            height: 28; radius: root.tileRadius
                            readonly property bool active: root.aiTool === modelData.id
                            color: active ? root.fillActive
                                  : segMa.containsMouse ? root.fillHover : root.fillIdle
                            border.color: (active || segMa.containsMouse) ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: (parent.active || segMa.containsMouse) ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 11
                                font.weight: parent.active ? Font.Medium : Font.Normal
                            }
                            MouseArea {
                                id: segMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.aiTool = parent.modelData.id
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                // ── Claude Code ──
                Item {
                    visible: aiPanel.showClaude
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "Claude Code"; color: root.ink
                        font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: aiPanel.clFresh ? "live" : "stale"
                        color: aiPanel.clFresh ? root.sumi : root.sealRaw
                        font.family: root.mono; font.pixelSize: 10
                    }
                }
                UiText {
                    visible: aiPanel.showClaude && !aiPanel.clHas
                    width: parent.width
                    text: "no data — run claude"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                }
                UsageRow { visible: aiPanel.showClaude && aiPanel.clHas; label: "5h"; pct: aiPanel.clPct5h; dim: !aiPanel.clFresh }
                UsageRow { visible: aiPanel.showClaude && aiPanel.clHas; label: "7d"; pct: aiPanel.clPct7d; dim: !aiPanel.clFresh }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas; k: "5h resets in"; v: root.aiFmtResetDetail(aiPanel.clReset5hTs) || "—" }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas; k: "7d resets in"; v: root.aiFmtResetDetail(aiPanel.clReset7dTs) || "—" }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas && aiPanel.clTokens !== ""; k: "Tokens"; v: aiPanel.clTokens }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas && aiPanel.clRate !== "";   k: "Rate"; v: aiPanel.clRate }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas && aiPanel.clToday > 0; k: "Today"; v: (aiPanel.clToday / 1e6).toFixed(2) + "M tok" }

                Rectangle { visible: false; width: parent.width; height: 1; color: root.sep }

                // ── OpenAI Codex ──
                Item {
                    visible: aiPanel.showCodex
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "OpenAI Codex" + (aiPanel.cxPlan ? "  · " + aiPanel.cxPlan : "")
                        color: root.ink
                        font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: aiPanel.cxFresh ? "live" : "stale"
                        color: aiPanel.cxFresh ? root.sumi : root.sealRaw
                        font.family: root.mono; font.pixelSize: 10
                    }
                }
                UiText {
                    visible: aiPanel.showCodex && !aiPanel.cxHas
                    width: parent.width
                    text: "no data — run codex"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                }
                UsageRow { visible: aiPanel.showCodex && aiPanel.cxWin0 !== null; label: aiPanel.cxWin0 ? aiPanel.cxWin0.label : ""; pct: aiPanel.cxWin0 ? aiPanel.cxWin0.pct : 0; dim: !aiPanel.cxFresh }
                UsageRow { visible: aiPanel.showCodex && aiPanel.cxWin1 !== null; label: aiPanel.cxWin1 ? aiPanel.cxWin1.label : ""; pct: aiPanel.cxWin1 ? aiPanel.cxWin1.pct : 0; dim: !aiPanel.cxFresh }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxWin0 !== null; k: (aiPanel.cxWin0 ? aiPanel.cxWin0.label : "") + " resets in"; v: root.aiFmtResetDetail(aiPanel.cxWin0 ? aiPanel.cxWin0.resetTs : 0) || "—" }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxWin1 !== null; k: (aiPanel.cxWin1 ? aiPanel.cxWin1.label : "") + " resets in"; v: root.aiFmtResetDetail(aiPanel.cxWin1 ? aiPanel.cxWin1.resetTs : 0) || "—" }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxHas; k: "General limit"; v: root.aiCodexStatusLabel(aiPanel.cxLimitStatus, aiPanel.cxLimitReachedType) }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxHas && aiPanel.cxRate !== "";   k: "Local activity (1h, incl. cached)"; v: aiPanel.cxRate }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxHas && aiPanel.cxToday > 0; k: "Today"; v: (aiPanel.cxToday / 1e6).toFixed(2) + "M tok" }

                Rectangle { visible: false; width: parent.width; height: 1; color: root.sep }

                // ── OpenCode ──
                Item {
                    visible: aiPanel.showOpenCode
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "OpenCode" + (aiPanel.ocPlan ? "  · " + aiPanel.ocPlan : "")
                        color: root.ink
                        font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: aiPanel.ocFresh ? "live" : "stale"
                        color: aiPanel.ocFresh ? root.sumi : root.sealRaw
                        font.family: root.mono; font.pixelSize: 10
                    }
                }
                UiText {
                    visible: aiPanel.showOpenCode && !aiPanel.ocHas
                    width: parent.width
                    text: "no data — run opencode"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                }
                UsageRow { visible: aiPanel.showOpenCode && aiPanel.ocHas; label: "5h"; pct: aiPanel.ocPct5h; dim: !aiPanel.ocFresh }
                UsageRow { visible: aiPanel.showOpenCode && aiPanel.ocHas; label: "7d"; pct: aiPanel.ocPct7d; dim: !aiPanel.ocFresh }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocTokens !== ""; k: "Tokens"; v: aiPanel.ocTokens }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocRate !== "";   k: "Rate"; v: aiPanel.ocRate }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocToday > 0; k: "Today"; v: (aiPanel.ocToday / 1e6).toFixed(2) + "M tok" }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocModel !== ""; k: "Latest"; v: aiPanel.ocModel }

                Item {
                    visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocModels.length > 0
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "MODELS"
                        color: root.sumiHi
                        font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "recent"
                        color: root.sumi
                        font.family: root.mono; font.pixelSize: 10
                    }
                }
                Repeater {
                    model: (aiPanel.showOpenCode && aiPanel.ocHas) ? aiPanel.ocModels : []
                    ModelUsageRow {
                        width: col.width
                        name: modelData.name || ""
                        totalLabel: modelData.totalLabel || ""
                        inputLabel: modelData.inputLabel || "0"
                        outputLabel: modelData.outputLabel || "0"
                        reasoningLabel: modelData.reasoningLabel || "0"
                        cacheReadLabel: modelData.cacheReadLabel || "0"
                        cacheWriteLabel: modelData.cacheWriteLabel || "0"
                        todayLabel: modelData.todayLabel || "0"
                        pct: parseInt(modelData.pct) || 0
                    }
                }
            }
        }
    }

    // Usage data + polling live in Theme.qml (shared with the bar pill); this panel
    // only renders from root.ai* and bumps the refresh cadence via root.aiUsageVisible.
}
