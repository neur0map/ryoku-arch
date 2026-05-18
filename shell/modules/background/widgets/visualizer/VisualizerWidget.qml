pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "visualizer"

    implicitWidth: 304
    implicitHeight: 104

    visibleWhenLocked: false
    needsColText: true

    readonly property bool _active: Config.options?.background?.widgets?.visualizer?.enable ?? false
    readonly property real dimFactor: {
        const raw = Number(Config.options?.background?.widgets?.visualizer?.dim ?? 0)
        return Math.max(0, Math.min(1, Number.isFinite(raw) ? raw / 100 : 0))
    }
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colBorder: Appearance.angelEverywhere ? "transparent"
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : "transparent"
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.ryokuEverywhere ? Appearance.ryoku.roundingNormal
        : Appearance.rounding.normal
    readonly property color dimTextColor: ColorUtils.mix(root.colText, Qt.rgba(0, 0, 0, 1), dimFactor)

    CavaProcess {
        id: cavaProcess
        active: root._active
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: ColorUtils.applyAlpha(root.colCard, 0.6)
        border.width: Appearance.angelEverywhere || Appearance.ryokuEverywhere || Appearance.auroraEverywhere ? 1 : 0
        border.color: ColorUtils.applyAlpha(root.colBorder, 0.6)
        visible: Appearance.angelEverywhere || Appearance.ryokuEverywhere || Appearance.auroraEverywhere
    }

    CavaVisualizer {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.ryokuEverywhere ? 4 : 0
        points: cavaProcess.points
        live: root._active
        barCount: 48
        barSpacing: 2
        barMinHeight: 1
        barRadius: 2
        colorLow: Appearance.angelEverywhere ? Appearance.angel.colSecondaryContainer
            : Appearance.ryokuEverywhere ? Appearance.ryoku.colSecondaryContainer
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondaryContainer
            : Appearance.colors.colSecondaryContainer
        colorMed: Appearance.angelEverywhere ? Appearance.angel.colPrimary
            : Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimary
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
            : Appearance.colors.colPrimary
        colorHigh: Appearance.angelEverywhere ? Appearance.angel.colTertiary
            : Appearance.ryokuEverywhere ? Appearance.ryoku.colTertiary
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
            : Appearance.colors.colTertiary
        opacity: 1.0 - root.dimFactor * 0.6
    }
}
