import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

Grid {
    id: root

    required property var config
    signal changed(string key, var value)

    columns: 2
    columnSpacing: Tokens.s2
    rowSpacing: Tokens.s2

    component SliderCell: Cell {
        id: cell

        property real minimum: 0
        property real maximum: 100
        property real setting: 0
        property string key: ""
        readonly property bool ratio: ["opacity", "islandScale", "osdScale"].includes(cell.key)

        width: (root.width - Tokens.s2) / 2
        height: implicitHeight
        controlWidth: 160
        value: String(cell.ratio ? Math.round(cell.setting * 100) : cell.setting)
        unit: cell.ratio ? "%" : "px"
        source: "shell.json"

        Slid {
            width: parent.width
            from: cell.minimum
            to: cell.maximum
            value: cell.setting
            onModified: value => root.changed(cell.key, value)
        }
    }

    SliderCell {
        label: qsTr("Bar height")
        key: "height"
        minimum: 32
        maximum: 56
        setting: root.config.height
    }
    SliderCell {
        label: qsTr("Island opacity")
        key: "opacity"
        minimum: 0.45
        maximum: 1
        setting: root.config.opacity
    }
    SliderCell {
        label: qsTr("Island padding")
        key: "padding"
        minimum: 6
        maximum: 24
        setting: root.config.padding
    }
    SliderCell {
        label: qsTr("Widget spacing")
        key: "spacing"
        minimum: 2
        maximum: 18
        setting: root.config.spacing
    }
    SliderCell {
        label: qsTr("Island gap")
        key: "islandGap"
        minimum: 6
        maximum: 32
        setting: root.config.islandGap
    }
    SliderCell {
        objectName: "nacre-frame-size"
        label: qsTr("Frame size")
        key: "frameSize"
        minimum: 2
        maximum: 24
        setting: root.config.frameSize
    }
    SliderCell {
        objectName: "nacre-frame-roundness"
        label: qsTr("Frame roundness")
        key: "frameRoundness"
        minimum: 0
        maximum: 32
        setting: root.config.frameRoundness
    }
    SliderCell {
        objectName: "nacre-edge-melt"
        label: qsTr("Edge melt")
        key: "edgeMelt"
        minimum: 1
        maximum: 32
        setting: root.config.edgeMelt
    }
    SliderCell {
        objectName: "nacre-island-size"
        label: qsTr("Island size")
        key: "islandScale"
        minimum: 0.65
        maximum: 1.25
        setting: root.config.islandScale
    }
    SliderCell {
        objectName: "nacre-osd-size"
        label: qsTr("OSD / popup size")
        key: "osdScale"
        minimum: 0.65
        maximum: 1.25
        setting: root.config.osdScale
    }
    Cell {
        width: (root.width - Tokens.s2) / 2
        height: implicitHeight
        controlWidth: 54
        label: qsTr("Desktop frame")
        value: root.config.frame ? qsTr("ON") : qsTr("OFF")
        source: "shell.json"

        Sw {
            objectName: "nacre-frame"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: root.config.frame
            onToggled: value => root.changed("frame", value)
        }
    }
    Cell {
        width: (root.width - Tokens.s2) / 2
        height: implicitHeight
        controlWidth: 54
        label: qsTr("Occupied workspaces")
        value: root.config.occupiedWorkspaces ? qsTr("ON") : qsTr("OFF")
        source: "shell.json"

        Sw {
            objectName: "nacre-occupied-workspaces"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: root.config.occupiedWorkspaces
            onToggled: value => root.changed("occupiedWorkspaces", value)
        }
    }
    Cell {
        width: (root.width - Tokens.s2) / 2
        height: implicitHeight
        controlWidth: 174
        label: qsTr("Workspace style")
        value: root.config.workspaceStyle.toUpperCase()
        source: "shell.json"

        Seg {
            objectName: "nacre-workspace-style"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: ["DOTS", "NUMBERS", "KANJI"]
            current: root.config.workspaceStyle.toUpperCase()
            onChose: key => root.changed("workspaceStyle", key.toLowerCase())
        }
    }
}
