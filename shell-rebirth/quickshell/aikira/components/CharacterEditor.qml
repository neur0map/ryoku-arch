import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule
import QtQuick.Controls

Item {
    id: root

    property bool isNew: AppState.editingCharacter === null

    Connections {
        target: AppState
        function onEditingCharacterChanged() { root.resetFields() }
    }
    Component.onCompleted: resetFields()

    function resetFields() {
        const c = AppState.editingCharacter
        fName.text   = c ? c.name             : ""
        fDesc.text   = c ? c.description      : ""
        fPers.text   = c ? c.personality      : ""
        fScen.text   = c ? c.scenario          : ""
        fFirst.text  = c ? c.first_message     : ""
        fTemp.text   = c ? (c.temperature !== null ? String(c.temperature) : "") : ""
        fTok.text    = c ? (c.max_tokens  !== null ? String(c.max_tokens)  : "") : ""
        proxyDrop.selectedId = c ? (c.proxy_id || "") : ""
        errMsg.visible = false
    }

    function doSave() {
        const name = fName.text.trim()
        if (!name) { errMsg.visible = true; return }
        errMsg.visible = false
        const data = {
            name:          name,
            description:   fDesc.text,
            personality:   fPers.text,
            scenario:      fScen.text,
            first_message: fFirst.text,
            temperature:   fTemp.text ? parseFloat(fTemp.text) : null,
            max_tokens:    fTok.text  ? parseInt(fTok.text)    : null,
            proxy_id:      proxyDrop.selectedId || null
        }
        if (isNew) {
            Api.createCharacter(data, function(err) {
                if (err) { errMsg.visible = true; return }
                AppState.refreshCharacters(); AppState.view = "chat"
            })
        } else {
            Api.updateCharacter(AppState.editingCharacter.id, data, function(err, updated) {
                if (err) { errMsg.visible = true; return }
                AppState.refreshCharacters()
                if (AppState.activeCharacter && AppState.activeCharacter.id === AppState.editingCharacter.id)
                    AppState.activeCharacter = updated
                AppState.view = "chat"
            })
        }
    }

    Rectangle { anchors.fill: parent; color: ColorsModule.Colors.background }

    Rectangle {
        id: ceHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 56
        color: ColorsModule.Colors.surface_container

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 10

            Rectangle {
                width: 30; height: 30; radius: 8
                color: backHov.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent"
                Behavior on color { ColorAnimation { duration: 110 } }
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 16
                    color: ColorsModule.Colors.on_surface_variant }
                MouseArea { id: backHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: AppState.view = "chat" }
            }

            Text {
                text: isNew ? "new character" : "edit character"
                font { pixelSize: 15; weight: Font.Medium; letterSpacing: 0.3 }
                color: ColorsModule.Colors.on_surface
            }
            Item { Layout.fillWidth: true }

            Text { id: errMsg; visible: false; text: "name is required"
                font.pixelSize: 11; color: ColorsModule.Colors.error }

            Rectangle {
                visible: !isNew; width: 30; height: 30; radius: 8
                color: delHov.containsMouse ? ColorsModule.Colors.error_container : "transparent"
                Behavior on color { ColorAnimation { duration: 110 } }
                Text { anchors.centerIn: parent; text: "⌫"; font.pixelSize: 14
                    color: ColorsModule.Colors.error }
                MouseArea { id: delHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: deleteDialog.visible = true }
            }

            Rectangle {
                width: 72; height: 32; radius: 16
                color: saveHov.containsMouse
                    ? ColorsModule.Colors.primary_fixed_dim : ColorsModule.Colors.primary
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "save"
                    font { pixelSize: 13; weight: Font.Medium }
                    color: ColorsModule.Colors.on_primary }
                MouseArea { id: saveHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root.doSave() }
            }
        }
    }

    Flickable {
        anchors { top: ceHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: formCol.implicitHeight + 48
        clip: true

        Column {
            id: formCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
            spacing: 22

            // Name
            Column {
                width: parent.width; spacing: 5
                Text { text: "NAME"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                Rectangle {
                    width: parent.width; height: 36; radius: 8
                    color: ColorsModule.Colors.surface_container_highest
                    border { width: fName.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                    Behavior on border.width { NumberAnimation { duration: 100 } }
                    TextInput {
                        id: fName
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: ColorsModule.Colors.on_surface
                        font { pixelSize: 13; family: "monospace" }
                        selectByMouse: true
                        Text {
                            anchors { fill: parent; leftMargin: 0; rightMargin: 0 }
                            verticalAlignment: Text.AlignVCenter
                            text: "character name"
                            font { pixelSize: 13; family: "monospace" }
                            color: ColorsModule.Colors.on_surface_variant
                            opacity: 0.35
                            visible: fName.text.length === 0
                        }
                    }
                }
            }

            // Proxy + temp + tokens row
            Row {
                width: parent.width; spacing: 16
                Column {
                    width: (parent.width - 32) * 0.5; spacing: 5
                    Text { text: "PROXY"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                    ProxyDropdown { id: proxyDrop; width: parent.width }
                }
                Column {
                    width: (parent.width - 32) * 0.25; spacing: 5
                    Text { text: "TEMPERATURE"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                    Rectangle {
                        width: parent.width; height: 36; radius: 8
                        color: ColorsModule.Colors.surface_container_highest
                        border { width: fTemp.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                        Behavior on border.width { NumberAnimation { duration: 100 } }
                        TextInput {
                            id: fTemp; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 12; family: "monospace" }
                            selectByMouse: true
                        }
                    }
                }
                Column {
                    width: (parent.width - 32) * 0.25; spacing: 5
                    Text { text: "MAX TOKENS"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                    Rectangle {
                        width: parent.width; height: 36; radius: 8
                        color: ColorsModule.Colors.surface_container_highest
                        border { width: fTok.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                        Behavior on border.width { NumberAnimation { duration: 100 } }
                        TextInput {
                            id: fTok; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 12; family: "monospace" }
                            selectByMouse: true
                        }
                    }
                }
            }

            Column {
                width: parent.width; spacing: 5
                Text { text: "DESCRIPTION"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                Text { text: "supports {{char}} and {{user}} placeholders"
                    font.pixelSize: 10; color: ColorsModule.Colors.on_surface_variant; opacity: 0.4 }
                Rectangle {
                    width: parent.width; height: 110
                    radius: 8; clip: true; color: ColorsModule.Colors.surface_container_highest
                    border { width: fDesc.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                    Behavior on border.width { NumberAnimation { duration: 100 } }
                    Flickable {
                        anchors { fill: parent; margins: 10 }
                        contentHeight: fDesc.implicitHeight
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        TextEdit {
                            id: fDesc; width: parent.width
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 12; family: "monospace" }
                            wrapMode: TextEdit.Wrap; selectByMouse: true
                        }
                    }
                }
            }

            // Personality
            Column {
                width: parent.width; spacing: 5
                Text { text: "PERSONALITY"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                Rectangle {
                    width: parent.width; height: 110
                    radius: 8; clip: true; color: ColorsModule.Colors.surface_container_highest
                    border { width: fPers.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                    Behavior on border.width { NumberAnimation { duration: 100 } }
                    Flickable {
                        anchors { fill: parent; margins: 10 }
                        contentHeight: fPers.implicitHeight
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        TextEdit {
                            id: fPers; width: parent.width
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 12; family: "monospace" }
                            wrapMode: TextEdit.Wrap; selectByMouse: true
                        }
                    }
                }
            }

            Column {
                width: parent.width; spacing: 5
                Text { text: "SCENARIO"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                Text { text: "sets the context / setting of the conversation"
                    font.pixelSize: 10; color: ColorsModule.Colors.on_surface_variant; opacity: 0.4 }
                Rectangle {
                    width: parent.width; height: 110
                    radius: 8; clip: true; color: ColorsModule.Colors.surface_container_highest
                    border { width: fScen.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                    Behavior on border.width { NumberAnimation { duration: 100 } }
                    Flickable {
                        anchors { fill: parent; margins: 10 }
                        contentHeight: fScen.implicitHeight
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        TextEdit {
                            id: fScen; width: parent.width
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 12; family: "monospace" }
                            wrapMode: TextEdit.Wrap; selectByMouse: true
                        }
                    }
                }
            }

            Column {
                width: parent.width; spacing: 5
                Text { text: "FIRST MESSAGE"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                Text { text: "shown at the start of every new chat (optional)"
                    font.pixelSize: 10; color: ColorsModule.Colors.on_surface_variant; opacity: 0.4 }
                Rectangle {
                    width: parent.width; height: 110
                    radius: 8; clip: true; color: ColorsModule.Colors.surface_container_highest
                    border { width: fFirst.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                    Behavior on border.width { NumberAnimation { duration: 100 } }
                    Flickable {
                        anchors { fill: parent; margins: 10 }
                        contentHeight: fFirst.implicitHeight
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        TextEdit {
                            id: fFirst; width: parent.width
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 12; family: "monospace" }
                            wrapMode: TextEdit.Wrap; selectByMouse: true
                        }
                    }
                }
            }

            Item { height: 16 }
        }
    }

    Rectangle {
        id: deleteDialog; visible: false
        anchors.fill: parent; color: "#99000000"; z: 20

        Rectangle {
            anchors.centerIn: parent; width: 340; height: 160; radius: 16
            color: ColorsModule.Colors.surface_container_highest

            Column {
                anchors { fill: parent; margins: 24 }
                spacing: 12
                Text { text: "delete this character?"; font { pixelSize: 15; weight: Font.Medium }
                    color: ColorsModule.Colors.on_surface }
                Text { text: "all conversations will be permanently deleted."
                    font.pixelSize: 12; color: ColorsModule.Colors.on_surface_variant; opacity: 0.7
                    wrapMode: Text.WordWrap; width: parent.width }
                Item { height: 4 }
                Row {
                    spacing: 10; anchors.right: parent.right
                    Rectangle {
                        width: 72; height: 32; radius: 16
                        color: cxHov.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent"
                        Text { anchors.centerIn: parent; text: "cancel"; font.pixelSize: 13
                            color: ColorsModule.Colors.on_surface_variant }
                        MouseArea { id: cxHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: deleteDialog.visible = false }
                    }
                    Rectangle {
                        width: 80; height: 32; radius: 16
                        color: ColorsModule.Colors.error_container
                        Text { anchors.centerIn: parent; text: "delete"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: ColorsModule.Colors.on_error_container }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Api.deleteCharacter(AppState.editingCharacter.id, function(err) {
                                    if (err) return
                                    AppState.refreshCharacters()
                                    if (AppState.activeCharacter &&
                                        AppState.activeCharacter.id === AppState.editingCharacter.id) {
                                        AppState.activeCharacter = null; AppState.messages = []; AppState.conversations = []
                                    }
                                    deleteDialog.visible = false; AppState.view = "chat"
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
