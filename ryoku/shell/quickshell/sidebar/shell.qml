//@ pragma DefaultEnv QSG_RENDER_LOOP = threaded

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

ShellRoot {
    id: root

    property bool shown: false
    property string targetMonitor: ""

    FileView {
        id: vibState
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/nvibrant-value"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = vibState.text();
        if (raw && raw.trim().length) {
            var pct = parseInt(raw.trim());
            if (!isNaN(pct)) {
                var v = Math.round(pct * 1023 / 100);
                Quickshell.execDetached(["nvibrant", String(v), "0", String(v)]);
            }
        }
    }

    Binding {
        target: Notifs
        property: "dnd"
        value: Flags.dnd
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "sidebar-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    IpcHandler {
        target: "sidebar"
        function show(mon: string): void {
            if (mon && mon.length) root.targetMonitor = mon;
            root.shown = true;
        }
        function hide(): void { root.shown = false; }
        function toggle(mon: string): void {
            if (root.shown) { root.shown = false; return; }
            if (mon && mon.length) root.targetMonitor = mon;
            root.shown = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property real s: modelData ? Math.min(modelData.height / 1080, 1.0) : 1
            readonly property real screenScale: modelData ? modelData.height / 1080 : 1
            readonly property real barBottom: 42 * screenScale
            readonly property bool active: root.shown && (root.targetMonitor === "" || root.targetMonitor === modelData.name)

            screen: modelData
            visible: true
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: win.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "sidebar"

            mask: win.active ? null : emptyRegion
            Region { id: emptyRegion }

            anchors { top: true; right: true; bottom: true; left: true }

            MouseArea {
                anchors.fill: parent
                enabled: win.active
                onClicked: root.shown = false
            }

            Sidebar {
                id: panel
                s: win.s
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: win.barBottom + 12 * win.screenScale
                anchors.rightMargin: 12 * win.screenScale
                anchors.bottomMargin: 12 * win.screenScale
                opened: win.active
                onRequestClose: root.shown = false
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: popupWin
            required property var modelData
            readonly property real s: modelData ? Math.min(modelData.height / 1080, 1.0) : 1
            readonly property real screenScale: modelData ? modelData.height / 1080 : 1

            screen: modelData
            visible: Notifs.popups.length > 0 && !root.shown
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "notif-popups"

            anchors { top: true; right: true }
            margins { top: 52 * popupWin.screenScale; right: 12 * popupWin.screenScale }

            implicitWidth: 420 * s
            implicitHeight: toastCol.implicitHeight

            Column {
                id: toastCol
                width: parent.width
                spacing: 10 * popupWin.s

                Repeater {
                    model: Notifs.popups

                    NotifPopup {
                        required property var modelData
                        width: parent.width
                        s: popupWin.s
                        notif: modelData
                    }
                }
            }
        }
    }
}
