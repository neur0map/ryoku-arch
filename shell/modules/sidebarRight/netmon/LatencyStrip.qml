import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Latency strip: small horizontal pill row showing ping round-trip times to
 * the default-route gateway and (when present) the active VPN tunnel's
 * gateway. Color-coded by threshold: green <50ms, yellow <200ms, red >=200ms
 * or timeout. Empty array yields zero pills (strip occupies no space).
 */
RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 6
    visible: RyokuNetMon.latency.length > 0

    required property color colAccent

    readonly property color colGood: root.colAccent
    readonly property color colWarn: Appearance.m3colors.m3warning ?? "#fabd2f"
    readonly property color colBad:  Appearance.m3colors.m3error ?? "#fb4934"

    function pillColor(rttMs, ok) {
        if (!ok) return root.colBad
        if (rttMs < 50) return root.colGood
        if (rttMs < 200) return root.colWarn
        return root.colBad
    }

    function pillText(item) {
        if (!item.ok) return item.label + " timeout"
        return item.label + " " + Math.round(item.rttMs) + " ms"
    }

    Repeater {
        model: RyokuNetMon.latency
        delegate: Rectangle {
            required property var modelData
            implicitWidth: pillLabel.implicitWidth + 18
            implicitHeight: pillLabel.implicitHeight + 6
            radius: implicitHeight / 2
            readonly property color pillCol: root.pillColor(modelData.rttMs, modelData.ok)
            color: ColorUtils.transparentize(pillCol, 0.85)
            border.width: 1
            border.color: pillCol
            StyledText {
                id: pillLabel
                anchors.centerIn: parent
                text: root.pillText(modelData)
                color: parent.pillCol
                font.weight: Font.Bold
                font.family: Appearance.font.family.monospace ?? "monospace"
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }
}
