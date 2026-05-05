import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property list<real> points: []
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color colorLow: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                           : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                           : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondaryContainer
                           : Appearance.colors.colSecondaryContainer
    property color colorMed: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                           : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                           : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
                           : Appearance.colors.colPrimary
    property color colorHigh: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                            : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                            : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
                            : Appearance.colors.colPrimary
    property int barCount: 50
    property real barSpacing: 2
    property real barMinHeight: 2
    property real barRadius: 3

    Row {
        id: barsRow
        anchors.fill: parent
        spacing: root.barSpacing

        Repeater {
            id: barsRepeater
            model: root.barCount

            Item {
                id: barWrapper
                required property int index
                width: (root.width - (root.barCount - 1) * root.barSpacing) / root.barCount
                height: root.height

                property real barValue: {
                    if (!root.live || root.points.length === 0) return 0;
                    const step = Math.max(1, Math.floor(root.points.length / root.barCount));
                    const start = index * step;
                    const end = Math.min(start + step, root.points.length);
                    let sum = 0;
                    let count = 0;
                    for (let i = start; i < end; i++) {
                        sum += root.points[i] || 0;
                        count++;
                    }
                    return count > 0 ? sum / count : 0;
                }

                property real normalizedValue: Math.min(1, barValue / root.maxVisualizerValue)
                property real barHeight: Math.max(root.barMinHeight, normalizedValue * (root.height / 2 - 2))
                property string intensity: normalizedValue > 0.7 ? "high" : normalizedValue > 0.35 ? "med" : "low"
                property color barColor: intensity === "high" ? root.colorHigh 
                                       : intensity === "med" ? root.colorMed 
                                       : root.colorLow

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    // Top bar (grows upward)
                    Rectangle {
                        width: barWrapper.width
                        height: barWrapper.barHeight
                        radius: root.barRadius
                        color: barWrapper.barColor
                        opacity: 0.9

                        Behavior on height {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: 100 }
                        }
                    }

                    // Bottom bar (grows downward, mirror)
                    Rectangle {
                        width: barWrapper.width
                        height: barWrapper.barHeight
                        radius: root.barRadius
                        color: barWrapper.barColor
                        opacity: 0.9

                        Behavior on height {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: 100 }
                        }
                    }
                }
            }
        }
    }
}
