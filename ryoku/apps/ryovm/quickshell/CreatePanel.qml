pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// The right half in Catalog mode: the chosen OS as the hero, a release and
// (when present) edition picker, then Create. Create downloads in a terminal, so
// the panel switches to a calm "downloading" state until the VM appears.
Item {
    id: pane

    readonly property var os: Vm.selectedOs
    property string release: ""
    property string edition: ""

    readonly property var editions: {
        if (!pane.os || !pane.release)
            return [];
        return pane.os.editions[pane.release] || [];
    }

    onOsChanged: {
        // quickget lists releases oldest-first — but the tail is often a dev
        // channel (ubuntu daily-live, kali weekly, nixos unstable). Default to
        // the newest STABLE: scan from the end, skip development slugs.
        var r = pane.os ? pane.os.releases : [];
        var dev = /(^|[-_])(daily|weekly|nightly|unstable|testing|preview|beta|canary|sid)([-_]|$)|^rc/i;
        var pick = "";
        for (var i = r.length - 1; i >= 0; i--)
            if (!dev.test(r[i])) { pick = r[i]; break; }
        pane.release = pick.length > 0 ? pick : (r.length > 0 ? r[r.length - 1] : "");
        pane._resetEdition();
    }
    onReleaseChanged: pane._resetEdition()
    function _resetEdition() {
        var e = pane.editions || [];
        // prefer the vanilla edition over whatever sorts first alphabetically.
        var ranked = ["standard", "default", "gnome", "plasma", "kde"];
        for (var i = 0; i < ranked.length; i++)
            if (e.indexOf(ranked[i]) >= 0) { pane.edition = ranked[i]; return; }
        pane.edition = e.length > 0 ? e[0] : "";
    }

    // empty state.
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: pane.os === null && !Vm.downloading
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "download"; size: 30; tint: Theme.faint }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: "Pick an OS to build a new machine"
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
        }
    }

    // downloading state: a live progress bar driven by the engine's JSON stream,
    // with Cancel (which SIGTERMs the fetcher and wipes the half-image).
    Column {
        anchors.centerIn: parent
        spacing: 16
        width: parent.width - 48
        visible: Vm.downloading

        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "download"; size: 34; tint: Theme.ember }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Vm.dlName
            color: Theme.bright; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({ "resolve": "Finding the fastest mirror", "download": "Downloading", "config": "Preparing the machine" })[Vm.dlPhase] || "Working"
            color: Theme.subtle; font.family: Theme.font; font.pixelSize: 13
        }

        // the bar: determinate from the fetcher, indeterminate sweep on fallback.
        Rectangle {
            width: parent.width
            height: 8
            radius: Theme.radius
            color: Theme.surfaceLo
            border.width: 1
            border.color: Theme.line
            clip: true
            Rectangle {
                visible: !Vm.dlIndeterminate
                width: parent.width * Vm.dlProgress
                height: parent.height
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.emberDeep }
                    GradientStop { position: 1.0; color: Theme.ember }
                }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                id: sweep
                visible: Vm.dlIndeterminate
                width: parent.width * 0.3
                height: parent.height
                radius: parent.radius
                color: Theme.ember
                SequentialAnimation on x {
                    running: sweep.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: -sweep.width; to: sweep.parent.width; duration: 1100; easing.type: Easing.InOutSine }
                }
            }
        }

        // percent + speed, or the last fallback log line.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            elide: Text.ElideRight
            text: Vm.dlIndeterminate
                ? (Vm.dlLog.length > 0 ? Vm.dlLog : "Working…")
                : (Math.round(Vm.dlProgress * 100) + "%" + (Vm.dlBps > 0 ? "  ·  " + (Vm.dlBps / 1048576).toFixed(1) + " MB/s" : ""))
            color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11
        }

        HubButton {
            anchors.horizontalCenter: parent.horizontalCenter
            label: "Cancel"
            icon: "close"
            accent: Theme.bad
            onClicked: Vm.cancelCreate()
        }
    }

    Item {
        anchors.fill: parent
        visible: pane.os !== null && !Vm.downloading

        Eyebrow {
            id: eyebrow
            anchors.top: parent.top
            anchors.left: parent.left
            text: "New machine"
        }

        // OS hero: big brand icon on a carbon stage.
        Item {
            id: hero
            anchors.top: eyebrow.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(150, parent.height * 0.26)

            BrutalPanel {
                anchors.fill: parent
                step: Theme.shadowStep
                surface: Theme.rail
                line: Theme.lineStrong

                RegMark {
                    x: parent.width - width - 16
                    y: 15
                    size: 12
                    tint: Theme.faint
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    OsIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72
                        height: 72
                        size: 72
                        slug: pane.os ? pane.os.os : ""
                        label: pane.os ? pane.os.name : ""
                        glyphTint: Theme.subtle
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pane.os ? pane.os.name : ""
                        color: Theme.bright; font.family: Theme.display; font.pixelSize: 22; font.weight: Font.DemiBold
                    }
                }
            }
        }

        Flickable {
            anchors.top: hero.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: createRow.top
            anchors.bottomMargin: 14
            contentWidth: width
            contentHeight: form.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: BoardScrollBar {}

            Column {
                id: form
                width: parent.width - 8
                spacing: 16

                Column {
                    width: parent.width
                    spacing: 8
                    SubLabel { text: "Release" }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: pane.os ? pane.os.releases : []
                            delegate: Chip {
                                required property var modelData
                                text: modelData
                                on: pane.release === modelData
                                onPicked: pane.release = modelData
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: pane.editions.length > 0
                    SubLabel { text: "Edition" }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: pane.editions
                            delegate: Chip {
                                required property var modelData
                                text: modelData
                                on: pane.edition === modelData
                                onPicked: pane.edition = modelData
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "quickemu downloads the official image and tunes the machine to your hardware. You can change cores, memory and the display mode after it lands in your Library."
                    color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                }
            }
        }

        Row {
            id: createRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38
            spacing: 10
            HubButton {
                primary: true
                icon: "download"
                label: "Create machine"
                enabled: pane.release.length > 0
                onClicked: Vm.createVm(pane.os.os, pane.release, pane.edition)
            }
        }
    }

    component SubLabel: Text {
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10
        font.letterSpacing: 1.5
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component Chip: Rectangle {
        id: chip
        property string text: ""
        property bool on: false
        signal picked()
        implicitWidth: ct.implicitWidth + 22
        height: 30
        color: chip.on ? Theme.frameBg : Theme.surfaceLo
        border.width: 1
        border.color: chip.on ? Theme.ember : (ch.hovered ? Qt.alpha(Theme.ember, 0.5) : Theme.line)
        antialiasing: false
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        Text { id: ct; anchors.centerIn: parent; text: chip.text; color: chip.on ? Theme.ember : Theme.cream; font.family: Theme.mono; font.pixelSize: 12; font.weight: Font.Medium }
        HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.picked() }
    }
}
