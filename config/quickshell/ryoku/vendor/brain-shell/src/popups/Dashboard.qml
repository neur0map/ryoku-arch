import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shapes"
import "../components"
import "../modules/Center/"
import '../services/'
import "../"

// Dashboard — PanelWindow required for TextInput keyboard focus on Wayland.
// Uses WlrKeyboardFocus.OnDemand so TextInputs inside pages receive key events.
//
// Positioning mirrors the original PopupWindow behaviour: the sizer's top sits
// exactly at the notch-bar bottom (topMargin: Theme.notchHeight), so there is
// no vertical offset compared to the PopupWindow version.

PanelWindow {
    id: root

    // Kept so existing instantiation sites that pass anchorWindow: … still compile.
    required property var anchorWindow

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: Theme.animDuration

    property string page: "home"

    // ── Per-page content widths ───────────────────────────────────────────────
    readonly property var _pageWidths: ({
        "home":     900,
        "stats":    900,
        "kanban":   900,
        "launcher": 560,
        "config":   900
    })

    function _applyPageWidth(p) {
        var w = _pageWidths[p]
        Popups.dashboardPageWidth = (w !== undefined) ? w : 900
    }

    onPageChanged: _applyPageWidth(page)

    // ── Surface config ────────────────────────────────────────────────────────
    color:   "transparent"
    visible: windowVisible

    anchors.top:   true
    anchors.left:  true
    anchors.right: true

    implicitHeight: Theme.notchHeight + Theme.dashboardHeight
    exclusionMode:  ExclusionMode.Ignore

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ── Mask — input/paint region limited to sizer only ──────────────────────
    mask: Region { item: maskProxy }
    Item {
        id:     maskProxy
        x:      ((root.width - sizer.width) / 2) + root.fw
        // topMargin matches sizer exactly — no fh offset
        y:      Theme.notchHeight
        width:  sizer.width -root.fw
        height: sizer.height-Theme.notchHeight
    }

    // ── Window visibility gate ────────────────────────────────────────────────
    property bool windowVisible: false

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) {
                closeTimer.stop()
                root.windowVisible = true
                root._applyPageWidth(root.page)
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.animDuration + 20
        onTriggered: {
            root.windowVisible = false
            tabBar.reset()
        }
    }

    // ── Sizer ─────────────────────────────────────────────────────────────────
    // topMargin: Theme.notchHeight places the sizer top exactly at the notch
    // bottom — identical to where PopupWindow put it. No fh subtraction, which
    // was the source of the vertical offset in the text-working variant.
    Item {
        id: sizer
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        width:  Popups.dashboardOpen ? Popups.dashboardPageWidth + 2 * root.fw : Theme.cNotchMinWidth + 2 * root.fw
        height: Popups.dashboardOpen ? Theme.dashboardHeight : Theme.notchHeight / 2

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }

        // ── Background ────────────────────────────────────────────────────────
        PopupShape {
            id: bg
            anchors.fill: parent
            attachedEdge: "top"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        // ── Content ───────────────────────────────────────────────────────────
        Item {
            id: content
            anchors {
                fill:         parent
                topMargin:    root.fh + 8
                leftMargin:   root.fw + 8
                rightMargin:  root.fw + 8
                bottomMargin: 8
            }

            opacity: Popups.dashboardOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.dashboardOpen
                        ? root.animDuration * 0.5
                        : root.animDuration * 0.15
                }
            }

            Column {
                anchors.fill: parent
                spacing: 0

                // ── Tab bar ───────────────────────────────────────────────────
                TabSwitcher {
                    id: tabBar
                    orientation: "horizontal"
                    width:       parent.width
                    currentPage: root.page
                    model: [
                        { key: "home",     icon: "󰋜",  label: "Home"   },
                        { key: "stats",    icon: "󰻠",  label: "System" },
                        { key: "kanban",   icon: "󰄬",  label: "Tasks"  },
                        { key: "launcher", icon: "󱓞",  label: "Apps"   },
                        { key: "config",   icon: "󰒓",  label: "Config" },
                    ]
                    onPageChanged: function(key) { root.page = key }
                }

                // ── Page area ─────────────────────────────────────────────────
                Item {
                    width:  parent.width
                    height: parent.height - tabBar.height

                    Item {
                        anchors.fill: parent
                        visible:      root.page === "home"
                        DashHome { anchors.fill: parent }
                    }

                    Item {
                        anchors.fill: parent
                        visible:      root.page === "stats"
                        DashStats { anchors.fill: parent }
                    }

                    Item {
                        anchors.fill: parent
                        visible:      root.page === "kanban"
                        KanbanBoard { anchors.fill: parent }
                    }

                    Item {
                        anchors.fill: parent
                        visible:      root.page === "launcher"
                        AppLauncher { anchors.fill: parent }
                    }

                    Item {
                        anchors.fill: parent
                        visible:      root.page === "config"
                        Text {
                            anchors.centerIn: parent
                            text:  "⚙️ Config"
                            color: Qt.rgba(1,1,1,0.3)
                            font.pixelSize: 16
                        }
                    }
                }
            }
        }
    }
}
