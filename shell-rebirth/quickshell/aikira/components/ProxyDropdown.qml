import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root
    height: 36

    property string selectedId: ""
    property bool   open:       false

    property string selectedName: {
        if (!selectedId || selectedId === "") return "none (use default)"
        const proxies = AppState.proxies
        if (!proxies || !proxies.length) return "loading…"
        const p = proxies.find(x => x && x.id === selectedId)
        return p ? p.name : "unknown"
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: ColorsModule.Colors.surface_container_highest
        border { width: open ? 1 : 0; color: ColorsModule.Colors.primary }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
            Text {
                Layout.fillWidth: true
                text: root.selectedName
                font { pixelSize: 12; family: "monospace" }
                color: root.selectedId ? ColorsModule.Colors.on_surface : ColorsModule.Colors.on_surface_variant
                opacity: root.selectedId ? 1 : 0.5
                elide: Text.ElideRight
            }
            Text {
                text: open ? "▲" : "▼"
                font.pixelSize: 9
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.6
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // Dropdown list
    Rectangle {
        visible: open
        anchors { top: parent.bottom; topMargin: 2; left: parent.left; right: parent.right }
        height: Math.min(((AppState.proxies ? AppState.proxies.length : 0) + 1) * 34, 200)
        radius: 8
        color: ColorsModule.Colors.surface_container_highest
        border { width: 1; color: ColorsModule.Colors.outline_variant }
        z: 100
        clip: true

        ListView {
            anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
            model: {
                const none = [{ id: "", name: "none (use default)" }]
                const proxies = AppState.proxies
                return proxies && proxies.length ? none.concat(proxies) : none
            }

            delegate: Item {
                width: ListView.view ? ListView.view.width : 0
                height: 32

                // Guard against null modelData
                property var pdata: modelData || { id: "", name: "" }

                Rectangle {
                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                    radius: 6
                    color: root.selectedId === pdata.id
                        ? ColorsModule.Colors.primary_container
                        : (itemHov.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent")

                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                        text: pdata.name || ""
                        font { pixelSize: 12; family: "monospace" }
                        color: root.selectedId === pdata.id
                            ? ColorsModule.Colors.on_primary_container
                            : ColorsModule.Colors.on_surface
                    }
                    MouseArea {
                        id: itemHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedId = pdata.id
                            root.open = false
                        }
                    }
                }
            }
        }
    }
}
