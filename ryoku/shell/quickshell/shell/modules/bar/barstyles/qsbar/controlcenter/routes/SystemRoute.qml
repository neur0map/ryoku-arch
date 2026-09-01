pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../kit"
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services as Services

// SYSTEM route (制御). The switches you reach for mid-work, and the shell's own
// actions. Every switch reflects live service state and writes back through that
// service, holding no copy of its own: DND / Keep awake / Game mode live in
// Flags, Night light in Toggles (a script it must run), Low power and Reduce
// motion in Perf (the one owner of performance.json). The actions call exactly
// what the desktop menu and the launcher already call.
Item {
    id: page
    property var root
    property var cc
    readonly property var tk: cc.tokens
    readonly property real colW: Math.min(page.width, tk.contentW)
    implicitHeight: col.implicitHeight

    // A labelled boolean row: the switch reflects `value` and writes back through
    // `toggled`. Every row but the first in its card carries a divider.
    component OnOff: SettingRow {
        id: r
        property bool value: false
        signal toggled(bool on)
        anchors.left: parent.left
        anchors.right: parent.right
        controlWidth: 54
        Sw {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: r.value
            onToggled: (v) => r.toggled(v)
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: page.colW
            spacing: page.tk.sectionGap

            Entrance {
                width: page.colW
                index: 0
                SettingCard {
                    width: page.colW
                    title: I18n.tr("SWITCHES")
                    kana: "\u5207\u63db"

                    OnOff {
                        label: I18n.tr("Do not disturb")
                        source: "flags.json"
                        value: Services.Flags.dnd
                        onToggled: (on) => Services.Flags.dnd = on
                    }
                    OnOff {
                        label: I18n.tr("Keep awake")
                        divider: true
                        source: "flags.json"
                        value: Services.Flags.keepAwake
                        onToggled: (on) => Services.Flags.keepAwake = on
                    }
                    OnOff {
                        label: I18n.tr("Game mode")
                        divider: true
                        source: "flags.json"
                        value: Services.Flags.gameMode
                        onToggled: (on) => Services.Flags.gameMode = on
                    }
                    OnOff {
                        label: I18n.tr("Night light")
                        divider: true
                        value: Services.Toggles.nightOn
                        // Toggles owns the hyprsunset script; flip only on a real change.
                        onToggled: (on) => { if (Services.Toggles.nightOn !== on) Services.Toggles.toggleNight(); }
                    }
                    OnOff {
                        label: I18n.tr("Low power")
                        divider: true
                        source: "performance.json"
                        value: Services.Perf.lowPower
                        onToggled: (on) => Services.Perf.setLowPower(on)
                    }
                    OnOff {
                        label: I18n.tr("Reduce motion")
                        divider: true
                        source: "performance.json"
                        value: Services.Perf.reduceMotionPref
                        onToggled: (on) => Services.Perf.setReduceMotion(on)
                    }
                }
            }

            Entrance {
                width: page.colW
                index: 1
                SettingCard {
                    width: page.colW
                    title: I18n.tr("ACTIONS")
                    kana: "\u884c\u52d5"

                    // An action whose label already names it does not need a band of
                    // its own underneath: the verb sits at the row's right, where every
                    // other control in the panel sits.
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        controlWidth: 110
                        label: I18n.tr("Reload shell")
                        desc: I18n.tr("Restart every surface.")
                        Btn {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            compact: true
                            text: I18n.tr("RELOAD")
                            onAct: {
                                Quickshell.execDetached(["ryoku-shell", "reload"]);
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 110
                        label: I18n.tr("Ryoku Settings")
                        desc: I18n.tr("Every knob, not just these.")
                        Btn {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            compact: true
                            text: I18n.tr("OPEN")
                            onAct: {
                                // Spawn (not execDetached) strips the crash handle, so
                                // qs -c hub starts clean instead of relaunching the shell.
                                Spawn.run(["sh", "-c", "flock -n -o /tmp/ryoku-hub.lock qs -c hub"]);
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 110
                        label: I18n.tr("Switch wallpaper")
                        desc: I18n.tr("Open the picker.")
                        Btn {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            compact: true
                            text: I18n.tr("SWITCH")
                            onAct: {
                                const st = Services.ShellState.forActive();
                                if (st)
                                    st.wallpaperSwitcherOpen = true;
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
