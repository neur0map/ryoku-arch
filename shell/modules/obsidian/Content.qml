pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property int panelWidth
    required property int panelHeight

    property var visibleMonth: new Date(ObsidianNotes.selectedDate.getFullYear(), ObsidianNotes.selectedDate.getMonth(), 1)

    readonly property int currMonth: visibleMonth.getMonth()
    readonly property int currYear: visibleMonth.getFullYear()
    readonly property int minNoteHeight: Math.max(110, Math.round(panelHeight * 0.16))
    readonly property int calendarChromeHeight: monthHeaderRow.implicitHeight + weekRow.implicitHeight + calendarContent.spacing * 2 + Tokens.padding.normal * 2
    readonly property int nonCalendarHeight: headerRow.implicitHeight + noteStatusRow.implicitHeight + minNoteHeight + Tokens.spacing.large * 3
    readonly property int calendarGridNaturalHeight: Math.round((panelWidth - Tokens.padding.normal * 2) * 0.7)
    readonly property int calendarGridHeight: Math.max(170, Math.min(calendarGridNaturalHeight, panelHeight - nonCalendarHeight - calendarChromeHeight))

    implicitWidth: panelWidth
    implicitHeight: panelHeight

    function sameDay(a: var, b: var): bool {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function insertAtCursor(text: string): void {
        noteEditor.insert(noteEditor.cursorPosition, text);
        noteEditor.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.large

        RowLayout {
            id: headerRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: titleIcon.implicitHeight + Tokens.padding.smaller * 2
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outline, 0.28)

                MaterialIcon {
                    id: titleIcon

                    anchors.centerIn: parent
                    text: "event_note"
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Calendar")
                    font.pointSize: Tokens.font.size.normal
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: ObsidianNotes.selectedIsoDate
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "open_in_new"
                type: IconButton.Tonal
                disabled: ObsidianNotes.opening
                onClicked: ObsidianNotes.openSelectedNote()
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: calendarContent.implicitHeight + Tokens.padding.normal * 2
            radius: Tokens.rounding.large
            color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outline, 0.22)

            ColumnLayout {
                id: calendarContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.normal
                spacing: Tokens.spacing.small

                RowLayout {
                    id: monthHeaderRow

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    IconButton {
                        icon: "chevron_left"
                        type: IconButton.Text
                        onClicked: root.visibleMonth = new Date(root.currYear, root.currMonth - 1, 1)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: monthGrid.title
                        horizontalAlignment: Text.AlignHCenter
                        color: Colours.palette.m3primary
                        font.pointSize: Tokens.font.size.normal
                        font.weight: 600
                        font.capitalization: Font.Capitalize
                    }

                    IconButton {
                        icon: "chevron_right"
                        type: IconButton.Text
                        onClicked: root.visibleMonth = new Date(root.currYear, root.currMonth + 1, 1)
                    }
                }

                DayOfWeekRow {
                    id: weekRow

                    Layout.fillWidth: true
                    locale: monthGrid.locale

                    delegate: StyledText {
                        required property var model

                        text: model.shortName
                        horizontalAlignment: Text.AlignHCenter
                        color: (model.day === 0 || model.day === 6) ? Colours.palette.m3secondary : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.smaller
                        font.weight: 600
                    }
                }

                MonthGrid {
                    id: monthGrid

                    Layout.fillWidth: true
                    implicitHeight: root.calendarGridHeight
                    month: root.currMonth
                    year: root.currYear
                    spacing: Tokens.spacing.smaller
                    locale: Qt.locale()

                    delegate: StyledRect {
                        id: dayItem

                        required property var model

                        readonly property bool selected: root.sameDay(dayItem.model.date, ObsidianNotes.selectedDate)
                        readonly property bool visibleMonthDay: dayItem.model.month === monthGrid.month

                        implicitWidth: implicitHeight
                        implicitHeight: dayText.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: selected ? Colours.palette.m3primary : dayItem.model.today ? Colours.palette.m3secondaryContainer : dayHover.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : "transparent"
                        border.width: selected ? 0 : dayItem.model.today ? 1 : 0
                        border.color: Qt.alpha(Colours.palette.m3secondary, 0.5)
                        opacity: visibleMonthDay ? 1 : 0.42

                        Behavior on color {
                            CAnim {}
                        }

                        StyledText {
                            id: dayText

                            anchors.centerIn: parent
                            text: monthGrid.locale.toString(dayItem.model.day)
                            color: dayItem.selected ? Colours.palette.m3onPrimary : dayItem.model.today ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.normal
                            font.weight: dayItem.selected || dayItem.model.today ? 700 : 500
                        }

                        MouseArea {
                            id: dayHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ObsidianNotes.selectDate(dayItem.model.date)
                        }
                    }
                }
            }
        }

        RowLayout {
            id: noteStatusRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                id: recentStrip

                Layout.fillWidth: true
                implicitHeight: Math.max(newNoteButton.implicitHeight, recentLabel.implicitHeight) + Tokens.padding.smaller * 2
                radius: Tokens.rounding.large
                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outline, 0.18)

                RowLayout {
                    id: recentRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small
                    anchors.rightMargin: Tokens.padding.small
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        id: recentLabel

                        text: qsTr("Recent")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                        font.weight: 600
                    }

                    Repeater {
                        model: ObsidianNotes.recentNotes

                        delegate: StyledRect {
                            id: recentChip

                            required property var modelData

                            readonly property bool selected: modelData.id === ObsidianNotes.currentEntryId

                            Layout.fillWidth: true
                            Layout.maximumWidth: 118
                            implicitHeight: newNoteButton.implicitHeight
                            radius: Tokens.rounding.full
                            color: selected ? Colours.palette.m3primary : recentMouse.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : Colours.palette.m3surfaceContainerHigh
                            border.width: selected ? 0 : 1
                            border.color: Qt.alpha(Colours.palette.m3outline, 0.18)
                            clip: true

                            Behavior on color {
                                CAnim {}
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.small
                                anchors.rightMargin: Tokens.padding.small
                                spacing: Tokens.spacing.smaller

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "edit_note"
                                    color: recentChip.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Tokens.font.size.small
                                    fill: recentChip.selected ? 1 : 0
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: recentChip.modelData.summary || recentChip.modelData.date
                                    color: recentChip.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Tokens.font.size.small
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: recentMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ObsidianNotes.selectRecentNote(modelData);
                                    noteEditor.forceActiveFocus();
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: ObsidianNotes.recentNotes.length === 0
                        text: qsTr("Saved notes show here")
                        color: Colours.palette.m3outline
                        font.pointSize: Tokens.font.size.small
                        elide: Text.ElideRight
                    }

                    IconButton {
                        id: newNoteButton

                        icon: "add"
                        type: IconButton.Text
                        onClicked: {
                            ObsidianNotes.startNewNote();
                            noteEditor.forceActiveFocus();
                        }
                    }
                }
            }

            StyledText {
                Layout.preferredWidth: 88
                text: ObsidianNotes.hasUnsavedDraft ? qsTr("Unsaved draft") : ObsidianNotes.lastSavedPath.length > 0 ? qsTr("Saved") : qsTr("Daily note")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        Item {
            id: noteViewport

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.minNoteHeight
            visible: true
            opacity: 1
            clip: true

            Behavior on opacity {
                Anim {}
            }

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: Colours.layer(Colours.palette.m3surfaceContainer, noteEditor.activeFocus ? 3 : 1)
                border.width: 1
                border.color: noteEditor.activeFocus ? Qt.alpha(Colours.palette.m3primary, 0.85) : Qt.alpha(Colours.palette.m3outline, 0.24)

                Behavior on color {
                    CAnim {}
                }

                Behavior on border.color {
                    CAnim {}
                }

                RowLayout {
                    id: noteToolbar

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        Layout.fillWidth: true
                        text: ObsidianNotes.selectedIsoDate
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "check_box"
                        type: IconButton.Text
                        onClicked: root.insertAtCursor("- [ ] ")
                    }

                    IconButton {
                        icon: "content_copy"
                        type: IconButton.Text
                        disabled: noteEditor.text.trim().length === 0
                        onClicked: {
                            Quickshell.clipboardText = noteEditor.text;
                            Toaster.toast(qsTr("Copied note"), ObsidianNotes.selectedIsoDate, "content_copy");
                        }
                    }

                    IconButton {
                        icon: "save"
                        type: ObsidianNotes.hasUnsavedDraft ? IconButton.Filled : IconButton.Tonal
                        disabled: ObsidianNotes.saving || noteEditor.text.trim().length === 0
                        onClicked: ObsidianNotes.saveNote(noteEditor.text)
                    }
                }

                Flickable {
                    id: noteScroll

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: noteToolbar.bottom
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Tokens.padding.normal
                    anchors.rightMargin: Tokens.padding.small
                    anchors.bottomMargin: Tokens.padding.small
                    contentWidth: width
                    contentHeight: Math.max(height, noteEditor.implicitHeight)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: noteScroll
                    }

                    TextArea {
                        id: noteEditor

                        width: noteScroll.width - Tokens.padding.small
                        height: Math.max(noteScroll.height, implicitHeight)
                        text: ObsidianNotes.draftText
                        placeholderText: qsTr("Markdown note")
                        placeholderTextColor: Colours.palette.m3outline
                        color: Colours.palette.m3onSurface
                        selectionColor: Colours.palette.m3primary
                        selectedTextColor: Colours.palette.m3onPrimary
                        font.family: Tokens.font.family.mono
                        font.pointSize: Tokens.font.size.smaller
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        background: null
                        onTextChanged: {
                            if (noteEditor.text !== ObsidianNotes.draftText)
                                ObsidianNotes.rememberDraft(noteEditor.text);
                        }

                        Connections {
                            target: ObsidianNotes

                            function onDraftTextChanged(): void {
                                if (noteEditor.text !== ObsidianNotes.draftText)
                                    noteEditor.text = ObsidianNotes.draftText;
                            }
                        }
                    }
                }
            }
        }
    }
}
