pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "Singletons"

// The detail view for one bundle, opened from its bento tile: the whole tool list
// with per-item install and remove, plus install-all and uninstall-all. Steady
// state comes from `statuses` (the page's status query); while an install or
// remove started here is running, the live report file overrides it until the
// page hands back a fresh status.
Item {
    id: detail

    property var bundle: ({})
    property var statuses: ({})
    property string reportDir: ""

    signal back()
    signal installAll()
    signal removeAll()
    signal installItem(string name)
    signal removeItem(string name)
    signal refreshRequested()

    property bool armed: false
    property var live: ({})

    onStatusesChanged: { detail.armed = false; detail.live = ({}); }

    readonly property var items: bundle.items || []

    function effStatus(name) {
        if (detail.armed && detail.live[name])
            return detail.live[name].status;
        if (detail.statuses[name] !== undefined)
            return detail.statuses[name];
        return "absent";
    }
    function effReason(name) {
        return (detail.armed && detail.live[name]) ? (detail.live[name].reason || "") : "";
    }
    function isHere(s) { return s === "present" || s === "installed"; }

    readonly property int installedCount: {
        var n = 0;
        for (var i = 0; i < items.length; i++)
            if (isHere(effStatus(items[i].name))) n++;
        return n;
    }
    readonly property bool anyPackagePresent: {
        for (var i = 0; i < items.length; i++)
            if (items[i].type === "package" && isHere(effStatus(items[i].name))) return true;
        return false;
    }

    function arm() { detail.armed = true; }

    FileView {
        id: report
        path: detail.reportDir + "/" + (detail.bundle.id || "_") + ".json"
        watchChanges: true
        onLoaded: detail.applyReport(report.text())
        onFileChanged: report.reload()
        onLoadFailed: {}
    }

    function applyReport(t) {
        try {
            var o = JSON.parse(t);
            detail.live = o.items || ({});
            if (o.phase === "done" && detail.armed)
                detail.refreshRequested();
        } catch (e) {}
    }

    // --- header -------------------------------------------------------------
    Item {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 86

        Row {
            id: backBtn
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron"
                size: 16
                weight: 2
                rotation: 90
                tint: backHover.hovered ? Theme.ember : Theme.dim
                Behavior on tint { ColorAnimation { duration: Theme.quick } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "All bundles"
                color: backHover.hovered ? Theme.ember : Theme.dim
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }

            HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: detail.back() }
        }

        Text {
            id: title
            anchors.left: parent.left
            anchors.top: backBtn.bottom
            anchors.topMargin: 12
            text: detail.bundle.name || ""
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: title.right
            anchors.leftMargin: 12
            anchors.verticalCenter: title.verticalCenter
            text: detail.bundle.sources || ""
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: detail.installedCount + " / " + detail.items.length
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 12
            }
            ActionPill {
                anchors.verticalCenter: parent.verticalCenter
                visible: detail.anyPackagePresent
                label: "Uninstall all"
                icon: "trash"
                danger: true
                onClicked: { detail.arm(); detail.removeAll(); }
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Install all"
                icon: "download"
                primary: true
                onClicked: { detail.arm(); detail.installAll(); }
            }
        }
    }

    Text {
        id: blurb
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 2
        text: detail.bundle.description || ""
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        lineHeight: 1.3
    }

    Rectangle {
        id: rule
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: blurb.bottom
        anchors.topMargin: 14
        height: 1
        color: Theme.line
    }

    // --- item list ----------------------------------------------------------
    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Column {
            id: col
            width: flick.width - 10
            topPadding: 4
            bottomPadding: 16

            Repeater {
                model: detail.items
                delegate: ExtraItemRow {
                    required property var modelData
                    width: col.width
                    itemName: modelData.name
                    summary: modelData.summary || ""
                    itemType: modelData.type
                    source: modelData.source || ""
                    status: detail.effStatus(modelData.name)
                    reason: detail.effReason(modelData.name)
                    onInstall: { detail.arm(); detail.installItem(modelData.name); }
                    onRemove: { detail.arm(); detail.removeItem(modelData.name); }
                }
            }
        }
    }
}
