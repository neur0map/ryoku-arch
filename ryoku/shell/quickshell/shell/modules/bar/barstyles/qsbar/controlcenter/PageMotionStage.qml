import QtQuick
import "../modules"

// Hosts the active page in a Loader and animates route/mode changes: fade+scale
// out (90ms), swap the source, fade+scale in (240ms OutCubic). Loaded pages get
// `root` and `cc` as initial properties.
Item {
    id: stage
    property var root
    property var cc
    property url pageUrl
    property int outMs: 90
    property int inMs: 240

    readonly property var item: ld.item

    onPageUrlChanged: seq.restart()

    Loader {
        id: ld
        anchors.fill: parent
        transformOrigin: Item.Center
        onLoaded: {
            if (item) {
                if (item.hasOwnProperty("root")) item.root = stage.root
                if (item.hasOwnProperty("cc")) item.cc = stage.cc
            }
        }
    }

    SequentialAnimation {
        id: seq
        ParallelAnimation {
            NumberAnimation { target: ld; property: "opacity"; to: 0.18; duration: stage.outMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: ld; property: "scale"; to: 0.965; duration: stage.outMs; easing.type: Easing.OutCubic }
        }
        ScriptAction {
            script: {
                if (String(stage.pageUrl) !== "") ld.setSource(stage.pageUrl, { root: stage.root, cc: stage.cc })
                else ld.source = ""
            }
        }
        ParallelAnimation {
            NumberAnimation { target: ld; property: "opacity"; to: 1.0; duration: stage.inMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: ld; property: "scale"; to: 1.0; duration: stage.inMs; easing.type: Easing.OutCubic }
        }
    }
}
