import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services as Services
import "../colors" as ColorsModule
import qs.components

Item {
    id: root
    property bool opened: false

    implicitHeight: opened ? 600 : 0
    implicitWidth: drawerWidth
    property int drawerWidth: 900

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    focus: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
            property: "implicitHeight"
        }
    }

    Popout {
        id: popoutBackground
        anchors.fill: parent
        clip: true
        alignment: 4
        radius: 32
        color: ColorsModule.Colors.surface_container_lowest

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(151, 204, 249, 0.02) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            width: 120
            height: 3
            anchors.top: parent.top
            anchors.topMargin: -1.5
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 1.5
            color: ColorsModule.Colors.primary
            opacity: 0.6
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 20
                color: ColorsModule.Colors.surface_container
                border.width: 1
                border.color: ColorsModule.Colors.outline_variant
                opacity: 0.8

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.05)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Text {
                        text: "Quick Notes"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: ColorsModule.Colors.on_surface
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    // Sort order toggle button
                    Button {
                        id: sortBtn
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        flat: true

                        contentItem: Text {
                            text: Services.Notes.sortDescending ? "↓" : "↑"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: ColorsModule.Colors.on_surface
                        }

                        background: Rectangle {
                            radius: 18
                            color: sortBtn.hovered
                                ? ColorsModule.Colors.surface_container_highest
                                : "transparent"
                            border.width: sortBtn.hovered ? 1 : 0
                            border.color: ColorsModule.Colors.outline_variant
                        }

                        onClicked: Services.Notes.toggleSortOrder()

                        ToolTip {
                            text: Services.Notes.sortDescending ? "Sort: Newest first" : "Sort: Oldest first"
                            delay: 300
                            visible: parent.hovered
                            background: Rectangle {
                                radius: 6
                                color: ColorsModule.Colors.surface_container_highest
                                border.width: 1
                                border.color: ColorsModule.Colors.outline_variant
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: Math.max(36, countText.contentWidth + 24)
                        Layout.alignment: Qt.AlignVCenter
                        radius: 18
                        color: ColorsModule.Colors.primary_container
                        opacity: Services.Notes.getNotesForCategory(
                            Services.Notes.currentCategory).length > 0 ? 1 : 0.4

                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(151, 204, 249, 0.1) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: Services.Notes.getNotesForCategory(
                                Services.Notes.currentCategory).length
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: ColorsModule.Colors.on_primary_container
                        }
                    }

                    Button {
                        id: addCategoryBtn
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        flat: true

                        contentItem: Text {
                            text: "+"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: ColorsModule.Colors.on_primary
                        }

                        background: Rectangle {
                            radius: 18
                            color: addCategoryBtn.hovered
                                ? Qt.darker(ColorsModule.Colors.primary_container, 1.2)
                                : ColorsModule.Colors.primary_container

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(151, 204, 249, 0.2)
                            }

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }

                        onClicked: categoryDialog.open()

                        ToolTip {
                            text: "Add new category"
                            delay: 300
                            visible: parent.hovered
                            background: Rectangle {
                                radius: 6
                                color: ColorsModule.Colors.surface_container_highest
                                border.width: 1
                                border.color: ColorsModule.Colors.outline_variant
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 16
                color: ColorsModule.Colors.surface_container
                border.width: 1
                border.color: ColorsModule.Colors.outline_variant
                opacity: 0.6

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    clip: true

                    RowLayout {
                        spacing: 8
                        height: parent.height

                        Repeater {
                            model: Services.Notes.categories

                            delegate: Item {
                                id: categoryItem
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: categoryTab.width

                                property bool isCurrent: Services.Notes.currentCategory === modelData
                                property bool isDefault: modelData === "notes"

                                Rectangle {
                                    id: categoryTab
                                    width: Math.min(
                                        categoryContent.implicitWidth + 24,
                                        categoryItem.isDefault ? categoryContent.implicitWidth + 24 : 160
                                    )
                                    height: 36

                                    radius: 18
                                    color: categoryItem.isCurrent
                                        ? ColorsModule.Colors.primary
                                        : mouseArea.containsMouse
                                            ? ColorsModule.Colors.surface_container_highest
                                            : ColorsModule.Colors.surface_container

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        border.width: categoryItem.isCurrent ? 2 : 0
                                        border.color: ColorsModule.Colors.primary
                                        opacity: 0.5
                                    }

                                    scale: mouseArea.containsMouse ? 1.05 : 1.0
                                    z: mouseArea.containsMouse ? 1 : 0
                                    Behavior on scale {
                                        NumberAnimation { duration: 150 }
                                    }
                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }

                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Services.Notes.setCurrentCategory(modelData)
                                    }

                                    RowLayout {
                                        id: categoryContent
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: categoryItem.isDefault ? 12 : 4
                                        spacing: 6

                                        Text {
                                            id: categoryText
                                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                            Layout.alignment: Qt.AlignVCenter
                                            color: categoryItem.isCurrent
                                                ? ColorsModule.Colors.on_primary
                                                : ColorsModule.Colors.on_surface
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: categoryItem.isDefault ? 120 : 80
                                        }

                                        // Command indicator
                                        Rectangle {
                                            visible: Services.Notes.categoryCommands[modelData] &&
                                                Services.Notes.categoryCommands[modelData] !== ""
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 8
                                            color: ColorsModule.Colors.primary
                                            opacity: 0.7

                                            Text {
                                                anchors.centerIn: parent
                                                text: "⌘"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: ColorsModule.Colors.on_primary
                                            }

                                            ToolTip {
                                                text: "Command: " + Services.Notes.categoryCommands[modelData]
                                                delay: 500
                                                visible: parent.hovered ? true : false
                                                background: Rectangle {
                                                    radius: 6
                                                    color: ColorsModule.Colors.surface_container
                                                    border.width: 1
                                                    border.color: ColorsModule.Colors.outline_variant
                                                }
                                            }
                                        }

                                        // Keep-open indicator
                                        Rectangle {
                                            visible: Services.Notes.categoryKeepOpen[modelData] === true
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 8
                                            color: ColorsModule.Colors.secondary
                                            opacity: 0.7

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🔓"
                                                font.pixelSize: 10
                                                color: ColorsModule.Colors.on_secondary
                                            }

                                            ToolTip {
                                                text: "Terminal stays open after command"
                                                delay: 500
                                                visible: parent.hovered ? true : false
                                                background: Rectangle {
                                                    radius: 6
                                                    color: ColorsModule.Colors.surface_container
                                                    border.width: 1
                                                    border.color: ColorsModule.Colors.outline_variant
                                                }
                                            }
                                        }

                                        // Buttons container for non-default categories
                                        RowLayout {
                                            visible: !categoryItem.isDefault
                                            spacing: 2
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.rightMargin: 4

                                            // Settings button
                                            Button {
                                                Layout.preferredWidth: 20
                                                Layout.preferredHeight: 20
                                                flat: true
                                                opacity: mouseArea.containsMouse ? 1 : 0.6

                                                contentItem: Text {
                                                    text: "⚙"
                                                    font.pixelSize: 12
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    color: categoryItem.isCurrent
                                                        ? ColorsModule.Colors.on_primary
                                                        : ColorsModule.Colors.on_surface
                                                }

                                                background: Rectangle {
                                                    radius: 10
                                                    color: parent.hovered
                                                        ? Qt.rgba(255, 255, 255, 0.2)
                                                        : "transparent"
                                                }

                                                onClicked: {
                                                    commandDialog.categoryName = modelData
                                                    commandDialog.commandText = Services.Notes.categoryCommands[modelData] || ""
                                                    commandDialog.keepOpen = Services.Notes.categoryKeepOpen[modelData] || false
                                                    commandDialog.open()
                                                }

                                                ToolTip {
                                                    text: "Configure category"
                                                    delay: 500
                                                    visible: parent.hovered
                                                    background: Rectangle {
                                                        radius: 6
                                                        color: ColorsModule.Colors.surface_container_highest
                                                        border.width: 1
                                                        border.color: ColorsModule.Colors.outline_variant
                                                    }
                                                }
                                            }

                                            // Delete button
                                            Button {
                                                Layout.preferredWidth: 20
                                                Layout.preferredHeight: 20
                                                flat: true
                                                opacity: mouseArea.containsMouse ? 1 : 0.6

                                                contentItem: Text {
                                                    text: "×"
                                                    font.pixelSize: 16
                                                    font.weight: Font.Bold
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    color: categoryItem.isCurrent
                                                        ? ColorsModule.Colors.on_primary
                                                        : ColorsModule.Colors.on_surface
                                                }

                                                background: Rectangle {
                                                    radius: 10
                                                    color: parent.hovered
                                                        ? Qt.rgba(255, 255, 255, 0.2)
                                                        : "transparent"
                                                }

                                                onClicked: Services.Notes.removeCategory(modelData)

                                                ToolTip {
                                                    text: "Remove category"
                                                    delay: 500
                                                    visible: parent.hovered
                                                    background: Rectangle {
                                                        radius: 6
                                                        color: ColorsModule.Colors.surface_container_highest
                                                        border.width: 1
                                                        border.color: ColorsModule.Colors.outline_variant
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: ColorsModule.Colors.surface_container
                border.width: 1
                border.color: ColorsModule.Colors.outline_variant

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.05)
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    ScrollBar.vertical.visible: true

                    ColumnLayout {
                        width: parent.width - 20
                        spacing: 12

                        Repeater {
                            model: Services.Notes.getNotesForCategory(
                                Services.Notes.currentCategory)

                            delegate: Rectangle {
                                id: noteCard
                                Layout.fillWidth: true
                                Layout.minimumHeight: 72
                                Layout.preferredHeight: isEditing ? 180 : Math.max(noteContentColumn.implicitHeight + 40, 72)

                                property bool isEditing: false
                                property var originalNote: modelData

                                radius: 16
                                color: ColorsModule.Colors.surface_container_high

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.width: 1
                                    border.color: noteMouseArea.containsMouse && !isEditing
                                        ? ColorsModule.Colors.primary
                                        : isEditing
                                            ? ColorsModule.Colors.secondary
                                            : Qt.rgba(255, 255, 255, 0.05)
                                    opacity: noteMouseArea.containsMouse && !isEditing ? 0.3 : 0.1
                                }

                                scale: noteMouseArea.containsMouse && !isEditing ? 1.02 : 1.0
                                z: noteMouseArea.containsMouse && !isEditing ? 1 : 0

                                Behavior on scale {
                                    NumberAnimation { duration: 200 }
                                }

                                MouseArea {
                                    id: noteMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: isEditing ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (!isEditing) {
                                            Services.Notes.executeNote(modelData)
                                            root.opened = false
                                        }
                                    }
                                }

                                // Edit mode UI - completely redesigned with proper layout
                                Loader {
                                    id: editLoader
                                    active: isEditing
                                    anchors.fill: parent
                                    anchors.margins: 16

                                    sourceComponent: Item {
                                        property alias mainInput: mainInputField
                                        property alias subtextInput: subtextInputField
                                        property var card: noteCard

                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 12

                                            TextField {
                                                id: mainInputField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 36
                                                text: originalNote.text
                                                placeholderText: "Main text (required)..."
                                                font.pixelSize: 14
                                                color: ColorsModule.Colors.on_surface
                                                background: Rectangle {
                                                    color: ColorsModule.Colors.surface_container
                                                    radius: 8
                                                    border.width: 1
                                                    border.color: ColorsModule.Colors.outline_variant
                                                }

                                                onAccepted: card.saveEdit()
                                            }

                                            TextField {
                                                id: subtextInputField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 36
                                                text: originalNote.subtext || ""
                                                placeholderText: "Subtext (optional)..."
                                                font.pixelSize: 13
                                                color: ColorsModule.Colors.on_surface_variant
                                                background: Rectangle {
                                                    color: ColorsModule.Colors.surface_container
                                                    radius: 8
                                                    border.width: 1
                                                    border.color: ColorsModule.Colors.outline_variant
                                                }

                                                onAccepted: card.saveEdit()
                                            }

                                            // Button row at the bottom
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignBottom
                                                spacing: 8

                                                Item { Layout.fillWidth: true } // Spacer

                                                Button {
                                                    text: "Cancel"
                                                    Layout.preferredWidth: 80
                                                    Layout.preferredHeight: 32

                                                    contentItem: Text {
                                                        text: "Cancel"
                                                        font.pixelSize: 12
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        color: ColorsModule.Colors.on_surface_variant
                                                    }

                                                    background: Rectangle {
                                                        radius: 16
                                                        color: parent.hovered
                                                            ? ColorsModule.Colors.surface_container_highest
                                                            : "transparent"
                                                        border.width: 1
                                                        border.color: ColorsModule.Colors.outline_variant
                                                    }

                                                    onClicked: card.isEditing = false
                                                }

                                                Button {
                                                    text: "Save"
                                                    Layout.preferredWidth: 80
                                                    Layout.preferredHeight: 32
                                                    enabled: mainInputField.text.trim().length > 0

                                                    contentItem: Text {
                                                        text: "Save"
                                                        font.pixelSize: 12
                                                        font.weight: Font.Medium
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        color: ColorsModule.Colors.on_primary
                                                    }

                                                    background: Rectangle {
                                                        radius: 16
                                                        color: parent.hovered && parent.enabled
                                                            ? Qt.darker(ColorsModule.Colors.primary, 1.2)
                                                            : ColorsModule.Colors.primary
                                                        opacity: parent.enabled ? 1 : 0.4
                                                    }

                                                    onClicked: card.saveEdit()
                                                }
                                            }
                                        }
                                    }
                                }

                                // Normal view mode
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 16
                                    visible: !isEditing

                                    ColumnLayout {
                                        id: noteContentColumn
                                        spacing: 6
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter

                                        // Main text (bold and slightly larger)
                                        Text {
                                            id: mainText
                                            text: modelData.text
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            color: ColorsModule.Colors.on_surface
                                            font.pixelSize: 15
                                            lineHeight: 1.4
                                            font.weight: Font.Medium
                                        }

                                        // Subtext (optional, smaller and muted)
                                        Text {
                                            visible: modelData.subtext && modelData.subtext.trim() !== ""
                                            text: modelData.subtext
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            color: ColorsModule.Colors.on_surface_variant
                                            font.pixelSize: 12
                                            lineHeight: 1.4
                                            font.weight: Font.Normal
                                            leftPadding: 8
                                        }

                                        // Command hint with keep-open status
                                        Text {
                                            visible: Services.Notes.categoryCommands[modelData.category] &&
                                                Services.Notes.categoryCommands[modelData.category] !== ""
                                            text: {
                                                var base = "▶ Click to run: " +
                                                    Services.Notes.categoryCommands[modelData.category].replace(/\$text/g, modelData.text).replace(/\$note/g, modelData.text)
                                                if (Services.Notes.categoryKeepOpen[modelData.category]) {
                                                    base += " (terminal stays open)"
                                                } else {
                                                    base += " (terminal closes)"
                                                }
                                                return base
                                            }
                                            font.pixelSize: 10
                                            color: ColorsModule.Colors.primary
                                            opacity: 0.7
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            leftPadding: 8
                                        }
                                    }

                                    // Action buttons container - fixed layout
                                    RowLayout {
                                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                        spacing: 4

                                        Button {
                                            id: editBtn
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            flat: true
                                            opacity: noteMouseArea.containsMouse ? 1 : 0.4

                                            contentItem: Text {
                                                text: "✎"
                                                font.pixelSize: 16
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                color: ColorsModule.Colors.on_surface
                                            }

                                            background: Rectangle {
                                                radius: 16
                                                color: editBtn.hovered
                                                    ? ColorsModule.Colors.surface_container_highest
                                                    : "transparent"
                                                border.width: 1
                                                border.color: editBtn.hovered
                                                    ? ColorsModule.Colors.outline_variant
                                                    : "transparent"
                                            }

                                            onClicked: {
                                                noteCard.isEditing = true
                                            }

                                            ToolTip {
                                                text: "Edit note"
                                                delay: 300
                                                visible: parent.hovered
                                                background: Rectangle {
                                                    radius: 6
                                                    color: ColorsModule.Colors.surface_container_highest
                                                    border.width: 1
                                                    border.color: ColorsModule.Colors.outline_variant
                                                }
                                            }
                                        }

                                        Button {
                                            id: copyBtn
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            flat: true
                                            opacity: noteMouseArea.containsMouse ? 1 : 0.5

                                            property bool copied: false

                                            contentItem: Text {
                                                text: copyBtn.copied ? "✓" : "⎘"
                                                font.pixelSize: 16
                                                font.family: "monospace"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                color: copyBtn.copied
                                                    ? ColorsModule.Colors.primary
                                                    : ColorsModule.Colors.on_surface
                                            }

                                            background: Rectangle {
                                                radius: 16
                                                color: copyBtn.hovered
                                                    ? copyBtn.copied
                                                        ? ColorsModule.Colors.primary_container
                                                        : ColorsModule.Colors.surface_container_highest
                                                    : "transparent"
                                                border.width: 1
                                                border.color: copyBtn.hovered
                                                    ? copyBtn.copied
                                                        ? ColorsModule.Colors.primary
                                                        : ColorsModule.Colors.outline_variant
                                                    : "transparent"
                                            }

                                            onClicked: {
                                                // Copy both main text and subtext if present
                                                var textToCopy = modelData.text
                                                if (modelData.subtext && modelData.subtext.trim() !== "") {
                                                    textToCopy += "\n\n" + modelData.subtext
                                                }
                                                Services.Notes.copy(textToCopy)
                                                copyBtn.copied = true
                                                copyTimer.start()
                                            }

                                            Timer {
                                                id: copyTimer
                                                interval: 1500
                                                onTriggered: copyBtn.copied = false
                                            }

                                            ToolTip {
                                                text: copyBtn.copied ? "Copied!" : "Copy to clipboard"
                                                delay: 300
                                                visible: parent.hovered
                                                background: Rectangle {
                                                    radius: 6
                                                    color: ColorsModule.Colors.surface_container_highest
                                                    border.width: 1
                                                    border.color: ColorsModule.Colors.outline_variant
                                                }
                                            }
                                        }

                                        Button {
                                            id: deleteBtn
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            flat: true
                                            opacity: noteMouseArea.containsMouse ? 1 : 0.4

                                            contentItem: Text {
                                                text: "🗑"
                                                font.pixelSize: 16
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                color: ColorsModule.Colors.on_surface
                                            }

                                            background: Rectangle {
                                                radius: 16
                                                color: deleteBtn.hovered
                                                    ? ColorsModule.Colors.error_container
                                                    : "transparent"
                                                border.width: 1
                                                border.color: deleteBtn.hovered
                                                    ? ColorsModule.Colors.error
                                                    : "transparent"
                                            }

                                            onClicked: {
                                                var index = Services.Notes.findNoteIndex(modelData.id)
                                                if (index !== -1) {
                                                    Services.Notes.remove(index)
                                                }
                                            }

                                            ToolTip {
                                                text: "Delete note"
                                                delay: 300
                                                visible: parent.hovered
                                                background: Rectangle {
                                                    radius: 6
                                                    color: ColorsModule.Colors.surface_container_highest
                                                    border.width: 1
                                                    border.color: ColorsModule.Colors.outline_variant
                                                }
                                            }
                                        }
                                    }
                                }

                                function saveEdit() {
                                    if (!editLoader.active) return

                                    var mainText = editLoader.item.mainInput.text.trim()
                                    if (mainText.length === 0) return

                                    var subText = editLoader.item.subtextInput.text

                                    var index = Services.Notes.findNoteIndex(originalNote.id)
                                    if (index !== -1) {
                                        Services.Notes.updateNote(
                                            index,
                                            mainText,
                                            subText,
                                            originalNote.category
                                        )
                                    }
                                    isEditing = false
                                }
                            }
                        }
                    }
                }
            }

            // Input area with main text and subtext fields
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                radius: 20
                color: ColorsModule.Colors.surface_container_high
                border.color: (mainInput.activeFocus || subtextInput.activeFocus)
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.outline_variant
                border.width: 2

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.1)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Main text input (required)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: mainInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            placeholderText: "Main text (required)..."
                            font.pixelSize: 14
                            placeholderTextColor: ColorsModule.Colors.on_surface_variant
                            color: ColorsModule.Colors.on_surface
                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                            }

                            onAccepted: addNote()
                        }

                        // Character count for main text
                        Text {
                            text: mainInput.text.length + "/200"
                            color: mainInput.text.length > 200
                                ? ColorsModule.Colors.error
                                : ColorsModule.Colors.on_surface_variant
                            font.pixelSize: 11
                            visible: mainInput.text.length > 0
                        }
                    }

                    // Subtext input (optional)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: subtextInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            placeholderText: "Subtext (optional details)..."
                            font.pixelSize: 13
                            placeholderTextColor: ColorsModule.Colors.on_surface_variant
                            color: ColorsModule.Colors.on_surface_variant
                            background: Rectangle {
                                color: "transparent"
                                border.width: 0
                                border.color: "transparent"
                            }

                            onAccepted: addNote()
                        }

                        // Character count for subtext
                        Text {
                            text: subtextInput.text.length + "/500"
                            color: subtextInput.text.length > 500
                                ? ColorsModule.Colors.error
                                : ColorsModule.Colors.on_surface_variant
                            font.pixelSize: 11
                            visible: subtextInput.text.length > 0
                        }
                    }

                    // Send button row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 10
                        spacing: 8

                        // Clear button
                        Button {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 32
                            visible: mainInput.text.length > 0 || subtextInput.text.length > 0

                            contentItem: Text {
                                text: "Clear"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: ColorsModule.Colors.on_surface_variant
                            }

                            background: Rectangle {
                                radius: 16
                                color: parent.hovered
                                    ? ColorsModule.Colors.surface_container_highest
                                    : "transparent"
                                border.width: 1
                                border.color: ColorsModule.Colors.outline_variant
                            }

                            onClicked: {
                                mainInput.text = ""
                                subtextInput.text = ""
                            }
                        }

                        Button {
                            id: sendButton
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 32
                            enabled: mainInput.text.trim().length > 0 && mainInput.text.length <= 200
                            opacity: enabled ? 1 : 0.4

                            contentItem: Text {
                                text: "Add Note ↑"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: ColorsModule.Colors.on_primary
                            }

                            background: Rectangle {
                                radius: 16
                                color: sendButton.hovered && sendButton.enabled
                                    ? Qt.darker(ColorsModule.Colors.primary_container, 1.2)
                                    : ColorsModule.Colors.primary_container

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.width: 2
                                    border.color: ColorsModule.Colors.primary
                                    opacity: 0.3
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                            }

                            onClicked: addNote()
                        }
                    }
                }
            }
        }
    }

    // Function to add note with main text and subtext
    function addNote() {
        if (mainInput.text.trim().length === 0) return
        if (mainInput.text.length > 200) return
        if (subtextInput.text.length > 500) return

        Services.Notes.add(mainInput.text, Services.Notes.currentCategory, subtextInput.text)
        mainInput.text = ""
        subtextInput.text = ""
    }

    CreateCategory{
        id: categoryDialog
    }

    ConfigureCategory{
        id: commandDialog
    }
}