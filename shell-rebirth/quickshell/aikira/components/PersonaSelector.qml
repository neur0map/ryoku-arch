import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root

    property bool showForm: false
    property var  editing:  null

    function openNew()   {
        editing = null
        pnField.text = ""
        pdField.text = ""
        pdDef.on = false
        pErrMsg.visible = false
        showForm = true
    }

    function openEdit(p) {
        editing = p
        pnField.text = p.name
        pdField.text = p.description || ""
        pdDef.on = p.is_default
        pErrMsg.visible = false
        showForm = true
    }

    Rectangle { anchors.fill: parent; color: ColorsModule.Colors.background }

    Rectangle {
        id: psHead
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 56
        color: ColorsModule.Colors.surface_container

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
            spacing: 12

            ColumnLayout {
                spacing: 2
                Text {
                    text: "Personas"
                    font { pixelSize: 15; weight: Font.Medium; letterSpacing: 0.3 }
                    color: ColorsModule.Colors.on_surface
                }
                Text {
                    text: "Click a card to use as active persona"
                    font.pixelSize: 10
                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.45
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 116; height: 32; radius: 16
                color: addPHov.containsMouse
                    ? ColorsModule.Colors.primary : ColorsModule.Colors.primary_container
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.centerIn: parent; spacing: 5
                    Text {
                        text: "＋"; font { pixelSize: 13 }
                        color: addPHov.containsMouse
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.on_primary_container
                    }
                    Text {
                        text: "Add persona"
                        font { pixelSize: 12; weight: Font.Medium }
                        color: addPHov.containsMouse
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.on_primary_container
                    }
                }

                MouseArea {
                    id: addPHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root.openNew()
                }
            }
        }
    }

    Item {
        anchors {
            top: psHead.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
            rightMargin: formPanel.width
        }
        visible: !AppState.personas || AppState.personas.length === 0

        ColumnLayout {
            anchors.centerIn: parent; spacing: 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "◈"; font.pixelSize: 44
                color: ColorsModule.Colors.primary; opacity: 0.15
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No personas yet"
                font { pixelSize: 14; letterSpacing: 0.3 }
                color: ColorsModule.Colors.on_surface_variant; opacity: 0.45
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Add a persona to tell the AI who you are"
                font.pixelSize: 11
                color: ColorsModule.Colors.on_surface_variant; opacity: 0.3
            }
        }
    }

    GridView {
        id: personaGrid
        anchors {
            top: psHead.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
            margins: 16
            rightMargin: formPanel.width + 16
        }
        cellWidth: 230; cellHeight: 138
        clip: true
        visible: AppState.personas && AppState.personas.length > 0
        model: AppState.personas

        delegate: Item {
            width: 222; height: 130

            property bool isActive: AppState.activePersona && AppState.activePersona.id === modelData.id
            property bool cardHovered: cardHoverHandler.hovered

            HoverHandler { id: cardHoverHandler }

            Rectangle {
                anchors { fill: parent; margins: 4 }
                radius: 14
                color: isActive
                    ? ColorsModule.Colors.secondary_container
                    : (cardHovered ? ColorsModule.Colors.surface_container_high : ColorsModule.Colors.surface_container)
                border {
                    width: modelData.is_default ? 1 : 0
                    color: ColorsModule.Colors.primary
                }
                Behavior on color { ColorAnimation { duration: 130 } }

                MouseArea {
                    id: cardHov
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AppState.activePersona = modelData
                        AppState.view = "chat"
                    }
                }

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: isActive
                                ? ColorsModule.Colors.primary
                                : ColorsModule.Colors.primary_container

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name.charAt(0).toUpperCase()
                                font { pixelSize: 15; weight: Font.Medium }
                                color: isActive
                                    ? ColorsModule.Colors.on_primary
                                    : ColorsModule.Colors.on_primary_container
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font { pixelSize: 13; weight: Font.Medium }
                                color: ColorsModule.Colors.on_surface
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 6
                                visible: modelData.is_default || isActive

                                Rectangle {
                                    visible: modelData.is_default
                                    width: defBadge.implicitWidth + 8; height: 16; radius: 8
                                    color: ColorsModule.Colors.primary; opacity: 0.15
                                    Text {
                                        id: defBadge
                                        anchors.centerIn: parent
                                        text: "default"; font.pixelSize: 9
                                        color: ColorsModule.Colors.primary
                                    }
                                }

                                Rectangle {
                                    visible: isActive
                                    width: actBadge.implicitWidth + 8; height: 16; radius: 8
                                    color: ColorsModule.Colors.secondary; opacity: 0.15
                                    Text {
                                        id: actBadge
                                        anchors.centerIn: parent
                                        text: "active"; font.pixelSize: 9
                                        color: ColorsModule.Colors.secondary
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 4
                            visible: cardHovered

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: editBtnHov.containsMouse
                                    ? ColorsModule.Colors.surface_container_highest : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent; text: "✎"; font.pixelSize: 12
                                    color: ColorsModule.Colors.on_surface_variant
                                }

                                MouseArea {
                                    id: editBtnHov; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => { mouse.accepted = true; root.openEdit(modelData) }
                                }
                            }

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: delBtnHov.containsMouse
                                    ? ColorsModule.Colors.error_container : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent; text: "×"; font.pixelSize: 15
                                    color: delBtnHov.containsMouse
                                        ? ColorsModule.Colors.on_error_container
                                        : ColorsModule.Colors.error
                                    opacity: delBtnHov.containsMouse ? 1 : 0.7
                                }

                                MouseArea {
                                    id: delBtnHov; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        Api.deletePersona(modelData.id, function(err) {
                                            if (!err) {
                                                if (AppState.activePersona && AppState.activePersona.id === modelData.id)
                                                    AppState.activePersona = null
                                                AppState.refreshPersonas()
                                            }
                                        })
                                    }
                                }
                            }
                        }
                    }

                    Item { height: 8 }

                    // Description
                    Text {
                        Layout.fillWidth: true
                        text: modelData.description || ""
                        font.pixelSize: 11
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }
            }
        }
    }

    Rectangle {
        id: formPanel
        visible: showForm
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: showForm ? 340 : 0
        color: ColorsModule.Colors.surface_container_low
        border { width: 1; color: ColorsModule.Colors.outline_variant }
        clip: true
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Flickable {
            anchors.fill: parent
            contentHeight: formContent.implicitHeight + 40
            clip: true

            Column {
                id: formContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 20

                // Panel header
                RowLayout {
                    width: parent.width

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: editing ? "Edit persona" : "New persona"
                            font { pixelSize: 14; weight: Font.Medium }
                            color: ColorsModule.Colors.on_surface
                        }
                        Text {
                            text: editing ? "Update persona details" : "Create a new persona"
                            font.pixelSize: 10
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.45
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: pcHov.containsMouse
                            ? ColorsModule.Colors.surface_container_high : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }
                        Text {
                            anchors.centerIn: parent; text: "×"; font.pixelSize: 18
                            color: ColorsModule.Colors.on_surface_variant
                        }
                        MouseArea {
                            id: pcHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: showForm = false
                        }
                    }
                }

                // Name field
                Column {
                    width: parent.width; spacing: 6

                    Text {
                        text: "NAME"
                        font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.6
                    }

                    Rectangle {
                        width: parent.width; height: 38; radius: 9
                        color: ColorsModule.Colors.surface_container_highest
                        border {
                            width: pnField.activeFocus ? 1 : 0
                            color: ColorsModule.Colors.primary
                        }
                        Behavior on border.width { NumberAnimation { duration: 100 } }

                        TextInput {
                            id: pnField
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 13; family: "monospace" }
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "e.g. Traveler"
                                font { pixelSize: 13; family: "monospace" }
                                color: ColorsModule.Colors.on_surface_variant; opacity: 0.3
                                visible: pnField.text.length === 0
                            }
                        }
                    }
                }

                // Description field
                Column {
                    width: parent.width; spacing: 6

                    Text {
                        text: "DESCRIPTION"
                        font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.6
                    }
                    Text {
                        text: "How you want to be described to the AI"
                        font.pixelSize: 10
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.38
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(90, pdField.implicitHeight + 24)
                        radius: 9; clip: true
                        color: ColorsModule.Colors.surface_container_highest
                        border {
                            width: pdField.activeFocus ? 1 : 0
                            color: ColorsModule.Colors.primary
                        }
                        Behavior on border.width { NumberAnimation { duration: 100 } }

                        TextEdit {
                            id: pdField
                            anchors { fill: parent; margins: 12 }
                            color: ColorsModule.Colors.on_surface
                            font { pixelSize: 13; family: "monospace" }
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                        }
                    }
                }

                // Default toggle
                RowLayout {
                    width: parent.width; spacing: 12

                    Rectangle {
                        id: pdDef; property bool on: false
                        width: 42; height: 24; radius: 12
                        color: on ? ColorsModule.Colors.primary : ColorsModule.Colors.surface_container_highest
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.on ? parent.width - width - 3 : 3
                            color: parent.on ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface_variant
                            opacity: parent.on ? 1 : 0.5
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: pdDef.on = !pdDef.on
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "default persona"
                            font { pixelSize: 12; weight: Font.Medium }
                            color: ColorsModule.Colors.on_surface
                        }
                        Text {
                            text: "used automatically in new chats"
                            font.pixelSize: 10
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.4
                        }
                    }
                }

                // Error message
                Text {
                    id: pErrMsg; visible: false
                    text: "name is required"
                    font.pixelSize: 11; color: ColorsModule.Colors.error
                }

                // Action buttons
                RowLayout {
                    width: parent.width; spacing: 8

                    // Delete button (editing only)
                    Rectangle {
                        visible: editing !== null
                        width: 80; height: 36; radius: 18
                        color: pdelHov.containsMouse
                            ? ColorsModule.Colors.error : ColorsModule.Colors.error_container
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent; text: "delete"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: pdelHov.containsMouse
                                ? "white" : ColorsModule.Colors.on_error_container
                        }

                        MouseArea {
                            id: pdelHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Api.deletePersona(editing.id, function(err) {
                                    if (!err) {
                                        if (AppState.activePersona && AppState.activePersona.id === editing.id)
                                            AppState.activePersona = null
                                        AppState.refreshPersonas()
                                        showForm = false
                                    }
                                })
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Cancel button
                    Rectangle {
                        width: 76; height: 36; radius: 18
                        color: pcanHov.containsMouse
                            ? ColorsModule.Colors.surface_container_high
                            : ColorsModule.Colors.surface_container_highest
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent; text: "cancel"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: ColorsModule.Colors.on_surface_variant
                        }

                        MouseArea {
                            id: pcanHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showForm = false
                        }
                    }

                    // Save button
                    Rectangle {
                        width: 76; height: 36; radius: 18
                        color: psvHov.containsMouse
                            ? ColorsModule.Colors.primary_fixed_dim : ColorsModule.Colors.primary
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent; text: "save"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: ColorsModule.Colors.on_primary
                        }

                        MouseArea {
                            id: psvHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const name = pnField.text.trim()
                                if (!name) { pErrMsg.visible = true; return }
                                pErrMsg.visible = false
                                const data = { name: name, description: pdField.text, is_default: pdDef.on }
                                if (!editing) {
                                    Api.createPersona(data, function(err) {
                                        if (err) { pErrMsg.visible = true; return }
                                        AppState.refreshPersonas(); showForm = false
                                    })
                                } else {
                                    Api.updatePersona(editing.id, data, function(err) {
                                        if (err) { pErrMsg.visible = true; return }
                                        AppState.refreshPersonas(); showForm = false
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
