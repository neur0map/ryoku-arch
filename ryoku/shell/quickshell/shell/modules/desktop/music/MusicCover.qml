import QtQuick
import Quickshell.Widgets
import "../../../components"

// The sleeve: one square plate that crossfades to the next cover instead of
// snapping, because the daemon resolves art asynchronously and a hard swap reads
// as a glitch mid-song. Two image slots alternate; the incoming one loads behind
// the outgoing one and is revealed once it has pixels.
Item {
    id: cover

    property string source: ""
    property real radius: 10
    property color plate: "#1a1a1a"
    property color ink: "#888888"
    property real s: 1

    property string frontSrc: ""
    property string backSrc: ""
    property bool showFront: true

    readonly property bool ready: (cover.showFront ? front.status : back.status) === Image.Ready

    onSourceChanged: {
        if (cover.source === (cover.showFront ? cover.frontSrc : cover.backSrc))
            return;
        if (cover.showFront) {
            cover.backSrc = cover.source;
            cover.showFront = false;
        } else {
            cover.frontSrc = cover.source;
            cover.showFront = true;
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: cover.radius
        color: cover.plate

        GlyphIcon {
            anchors.centerIn: parent
            visible: !cover.ready
            width: Math.round(parent.width * 0.26)
            height: width
            name: "music"
            color: cover.ink
            stroke: 1.4
            opacity: 0.55
        }

        Image {
            id: front
            anchors.fill: parent
            source: cover.frontSrc
            opacity: cover.showFront && front.status === Image.Ready ? 1 : 0
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.round(cover.width * 2)
            sourceSize.height: Math.round(cover.height * 2)
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        Image {
            id: back
            anchors.fill: parent
            source: cover.backSrc
            opacity: !cover.showFront && back.status === Image.Ready ? 1 : 0
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.round(cover.width * 2)
            sourceSize.height: Math.round(cover.height * 2)
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
    }

    // hairline rim, so a pale sleeve still reads as a seated plate.
    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
    }
}
