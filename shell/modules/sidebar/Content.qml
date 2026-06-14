import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Ryoku.Config
import qs.components
import qs.services

Item {
    id: root

    required property Props props
    required property DrawerVisibilities visibilities

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.normal

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Math.round(Tokens.rounding.normal * Config.sidebar.rounding)
            color: Colours.tPalette.m3surfaceContainerLow

            layer.enabled: Config.sidebar.shadow
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3shadow
                shadowVerticalOffset: 2
                shadowBlur: 0.7
                shadowOpacity: 0.55
            }

            NotifDock {
                props: root.props
                visibilities: root.visibilities
            }
        }

        StyledRect {
            Layout.topMargin: Tokens.padding.large - layout.spacing
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}
