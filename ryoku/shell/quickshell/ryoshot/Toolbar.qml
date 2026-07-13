import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: tb
    implicitWidth: glass.implicitWidth
    implicitHeight: glass.implicitHeight

    property string activeTool: "rect"
    property color activeColor: "#e2342a"
    property int activeWidth: 4
    property bool canUndo: false
    property bool canRedo: false
    property bool settingsOpen: false
    property bool activeRough: false

    readonly property real gearCenterX: gear.x + row.x + gear.width / 2

    signal toolPicked(string tool)
    signal colorPicked(color c)
    signal widthPicked(int w)
    signal undoRequested()
    signal redoRequested()
    signal copyRequested()
    signal saveRequested()
    signal uploadRequested()
    signal settingsRequested()
    signal beautifyRequested()
    signal roughToggled()

    readonly property color glassBg: Qt.rgba(22 / 255, 17 / 255, 11 / 255, 0.92)
    readonly property color glassBorder: Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.14)
    readonly property color vermilion: "#e2342a"
    readonly property color idle: "#c7bfae"
    readonly property color sep: Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.14)

    // the desktop brand seal, user-overridable via ~/.config/ryoku/brand.json
    // (Ryoku Settings -> Shell -> Global). the beautify button follows markText;
    // empty/absent falls back to the 力 default, so this never seeds.
    readonly property string mark: brandAdapter.markText.length > 0 ? brandAdapter.markText : "\u529b"
    FileView {
        id: brandFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/brand.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter { id: brandAdapter; property string markText: "力" }
    }

    readonly property var tools: [
        { id: "select",  icon: "select",  implemented: true },
        { id: "rect",    icon: "rect",    implemented: true },
        { id: "ellipse", icon: "ellipse", implemented: true },
        { id: "line",    icon: "line",    implemented: true },
        { id: "arrow",   icon: "arrow",   implemented: true },
        { id: "pen",     icon: "pen",     implemented: true },
        { id: "marker",  icon: "marker",  implemented: true },
        { id: "text",    icon: "text",    implemented: true },
        { id: "blur",    icon: "blur",    implemented: true },
        { id: "pixelate", icon: "pixelate", implemented: true },
        { id: "magnify", icon: "magnify", implemented: true },
        { id: "counter", icon: "counter", implemented: true }
    ]

    readonly property var swatches: [
        "#e2342a", "#ffffff", "#1a1a1a", "#e23b3b", "#f2c14e", "#5bbf73", "#4f8fe0"
    ]

    readonly property var widths: [
        { id: 2, dot: 5 },
        { id: 4, dot: 9 },
        { id: 7, dot: 13 }
    ]

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: 10
        color: tb.glassBg
        border.color: tb.glassBorder
        border.width: 1
        implicitWidth: row.implicitWidth + 12
        implicitHeight: row.implicitHeight + 12

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: tb.tools
                IconButton {
                    required property var modelData
                    icon: modelData.icon
                    active: tb.activeTool === modelData.id
                    dim: !modelData.implemented
                    onClicked: { if (modelData.implemented) tb.toolPicked(modelData.id); }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            Repeater {
                model: tb.swatches
                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    color: modelData
                    readonly property bool sel: Qt.colorEqual(tb.activeColor, modelData)
                    border.color: sel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.18)
                    border.width: sel ? 2 : 1
                    scale: swMa.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    MouseArea { id: swMa; anchors.fill: parent; hoverEnabled: true; onClicked: tb.colorPicked(modelData) }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            Repeater {
                model: tb.widths
                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 6
                    readonly property bool sel: tb.activeWidth === modelData.id
                    color: sel ? tb.vermilion : (whMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                    MouseArea { id: whMa; anchors.fill: parent; hoverEnabled: true; onClicked: tb.widthPicked(modelData.id) }
                    Rectangle {
                        anchors.centerIn: parent
                        width: modelData.dot
                        height: modelData.dot
                        radius: width / 2
                        color: parent.sel ? "#ffffff" : tb.idle
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton { icon: "sketch"; active: tb.activeRough; onClicked: tb.roughToggled() }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton { icon: "undo"; dim: !tb.canUndo; onClicked: { if (tb.canUndo) tb.undoRequested(); } }
            IconButton { icon: "redo"; dim: !tb.canRedo; onClicked: { if (tb.canRedo) tb.redoRequested(); } }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton { icon: "copy"; onClicked: tb.copyRequested() }
            IconButton { icon: "save"; onClicked: tb.saveRequested() }
            IconButton { icon: "upload"; onClicked: tb.uploadRequested() }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 7
                color: beautMa.containsMouse ? Qt.rgba(226 / 255, 52 / 255, 42 / 255, 0.16) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: tb.mark
                    color: tb.vermilion
                    font.family: "Noto Sans CJK JP"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                MouseArea { id: beautMa; anchors.fill: parent; hoverEnabled: true; onClicked: tb.beautifyRequested() }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton {
                id: gear
                icon: "gear"
                active: tb.settingsOpen
                onClicked: { tb.settingsOpen = !tb.settingsOpen; tb.settingsRequested(); }
            }
        }
    }
}
