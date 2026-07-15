import QtQuick
import "Singletons"

// The machine's ticket: a boarding-pass hero on the brutalist stage. Left is
// the tear-off stub — hanko seal, split-flap power state. A punched perforation
// column separates it from the manifest: the machine's name finally in display
// type, an IATA-style field grid of the real hardware, and the annunciator row
// reporting each subsystem as a lit or dark tile. It informs, loudly.
Item {
    id: stage

    property string name: ""
    property string guest: "linux"
    property string os: ""
    property bool running: false
    property string mode: "gtk"
    property string ssh: ""
    property string spice: ""
    property string cores: "auto"
    property string ram: "auto"
    property real diskUsed: 0
    property string diskCap: ""
    property bool installed: false
    property bool disposable: false
    property bool sshReady: false
    property bool sealed: false
    property bool tpmOn: false
    property bool uefiOn: true

    // one manifest field: an 8px caps label over a mono value.
    component Field: Column {
        id: fld
        property string k: ""
        property string v: ""
        property color vc: Theme.cream
        spacing: 3
        Text {
            text: fld.k
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
        }
        Text {
            text: fld.v
            color: fld.vc
            font.family: Theme.mono
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }

    BrutalPanel {
        anchors.fill: parent
        step: Theme.shadowStep
        surface: Theme.rail
        line: stage.running ? Qt.alpha(Theme.ember, 0.55) : Theme.lineStrong
        Behavior on line { ColorAnimation { duration: Theme.medium } }

        RegMark {
            x: parent.width - width - 16
            y: 15
            size: 12
            tint: stage.running ? Qt.alpha(Theme.ember, 0.7) : Theme.faint
            Behavior on tint { ColorAnimation { duration: Theme.medium } }
        }

        // ---- the stub: seal + power flap --------------------------------------
        Item {
            id: stub
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 148

            Column {
                anchors.centerIn: parent
                spacing: 18

                // the carrier mark: real brand art, with the yard's registration
                // hanko stamped over its corner like a customs seal.
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96
                    height: 92

                    OsIcon {
                        x: 2; y: 2
                        width: 64
                        height: 64
                        size: 64
                        slug: stage.os
                        label: stage.os.length > 0 ? stage.os : stage.guest
                        opacity: stage.running ? 1 : 0.75
                        Behavior on opacity { NumberAnimation { duration: Theme.medium } }
                    }
                    HankoSeal {
                        x: 46; y: 42
                        size: 48
                        title: stage.os.length > 0 ? stage.os : stage.guest
                        glyph: (stage.os.length > 0 ? stage.os : stage.guest).charAt(0).toUpperCase()
                        ink: stage.running ? Theme.brand : Theme.dim
                        inkOpacity: stage.running ? 0.9 : 0.5
                        Behavior on ink { ColorAnimation { duration: Theme.medium } }
                    }
                }

                FlapWord {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: stage.running ? (stage.disposable ? "BURNING" : "RUNNING") : "STOPPED"
                    pad: 7
                    cellW: 13
                    cellH: 20
                    fontPx: 11
                    ink: stage.running ? (stage.disposable ? Theme.ember : Theme.ok) : Theme.dim
                }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RYOVM · PASS"
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 8
                font.letterSpacing: 2
            }
        }

        // ---- perforation: punched holes through the ticket --------------------
        Column {
            id: perf
            anchors.left: stub.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            width: 8
            spacing: 9
            Repeater {
                model: Math.max(0, Math.floor((perf.height + 9) / 15))
                delegate: Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 6
                    height: 6
                    radius: 3            // a punched hole is round; it is absence, not chrome
                    color: Theme.bgBot
                    border.width: 1
                    border.color: Theme.shadow
                }
            }
        }

        // ---- the manifest ------------------------------------------------------
        Column {
            anchors.left: perf.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 26
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Column {
                width: parent.width
                spacing: 2
                Text {
                    // long quickget names (artixlinux-20260402-base-openrc) must
                    // stay inside the ticket: shrink display type a step for the
                    // long ones, elide whatever still overflows.
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: stage.name.length > 0 ? stage.name : "machine"
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: stage.name.length > 22 ? 21 : 28
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (stage.guest || "linux").toUpperCase() + " GUEST · QEMU/KVM CARRIER"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.8
                }
            }

            Grid {
                columns: 3
                columnSpacing: 34
                rowSpacing: 12
                Field { k: "Cores"; v: stage.cores === "auto" ? "AUTO" : stage.cores }
                Field { k: "Memory"; v: stage.ram === "auto" ? "AUTO" : stage.ram }
                Field {
                    k: "Disk"
                    v: stage.diskUsed > 0
                        ? Vm.human(stage.diskUsed) + (stage.diskCap.length > 0 ? " / " + stage.diskCap : "")
                        : (stage.diskCap.length > 0 ? stage.diskCap + " · EMPTY" : "NONE")
                }
                Field { k: "Mode"; v: ({ "gtk": "WINDOW", "spice": "SPICE", "none": "HEADLESS" })[stage.mode] || stage.mode }
                Field {
                    k: "SSH"
                    v: stage.running && stage.ssh.length > 0
                        ? ":" + stage.ssh + (stage.sshReady ? "" : " · no answer")
                        : "—"
                    vc: stage.running && stage.sshReady ? Theme.ok : Theme.faint
                }
                Field { k: "Console"; v: stage.running && stage.spice.length > 0 ? "SPICE" : "—"; vc: stage.running && stage.spice.length > 0 ? Theme.ok : Theme.faint }
            }

            // the annunciator cluster: a rigid instrument matrix — uniform
            // tiles, hard column registration, however narrow the pane. Dark
            // means honestly off.
            Grid {
                id: annGrid
                columns: Math.max(3, Math.floor((parent.width + 5) / 59))
                columnSpacing: 5
                rowSpacing: 5
                Annunciator { label: "KVM"; lit: Vm.caps.kvm === true; tileW: 54 }
                Annunciator { label: "UEFI"; lit: stage.uefiOn; tileW: 54 }
                Annunciator { label: "TPM"; lit: stage.tpmOn; tileW: 54 }
                Annunciator { label: "DISK"; lit: stage.installed; tileW: 54 }
                Annunciator { label: "NET"; lit: stage.running; tileW: 54 }
                Annunciator { label: "SSH"; lit: stage.running && stage.sshReady; tileW: 54 }
                Annunciator { label: "SPICE"; lit: stage.running && stage.spice.length > 0; tileW: 54 }
                Annunciator { label: "SEALED"; lit: stage.sealed; litColor: Theme.gold; tileW: 54 }
                Annunciator { label: "BURN"; lit: stage.running && stage.disposable; warn: true; litColor: Theme.ember; tileW: 54 }
            }
        }
    }
}
