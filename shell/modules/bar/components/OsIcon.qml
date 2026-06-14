import QtQuick
import Ryoku.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    readonly property int logoSize: Math.round(Tokens.font.size.large * 1.6)
    readonly property int iconSize: Math.round(Tokens.font.size.large * 1.2)

    implicitWidth: logoSize
    implicitHeight: logoSize

    StateLayer {
        anchors.fill: parent
        radius: Tokens.rounding.full
        onClicked: {
            const visibilities = Visibilities.getForActive();
            visibilities.launcher = !visibilities.launcher;
        }
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent
        sourceComponent: SysInfo.isDefaultLogo ? ryokuLogo : distroIcon
    }

    Component {
        id: ryokuLogo

        Logo {
            implicitWidth: root.logoSize
            implicitHeight: root.logoSize
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: root.iconSize
            colour: Colours.palette.m3tertiary
        }
    }
}
