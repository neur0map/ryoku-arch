import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.threeIsland.dynamicIsland
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colVoice: Appearance.ryokuEverywhere
        ? (Appearance.ryoku.colSecondary ?? "#c090e0")
        : (Appearance.colors.colSecondary ?? "#c090e0")

    Component.onCompleted: Cava.start()
    Component.onDestruction: Cava.stop()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        color: Qt.rgba(root.colVoice.r, root.colVoice.g, root.colVoice.b, 0.16)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "🎤"
            font.pixelSize: Appearance.font.pixelSize.normal
        }

        CavaWaveform {
            Layout.alignment: Qt.AlignVCenter
            barColor: root.colVoice
            barWidth: 2
            maxBarHeight: 14
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Translation.tr("Listening")
            font.pixelSize: Appearance.font.pixelSize.smaller
            opacity: 0.7
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onPressed: VoiceSearch.stop()
    }

    StyledToolTip {
        text: Translation.tr("Listening - click to cancel")
        extraVisibleCondition: mouseArea.containsMouse
    }
}
