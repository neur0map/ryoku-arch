pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    readonly property int rounding: floating ? 0 : Tokens.rounding.large

    property alias floating: session.floating
    property alias active: session.active
    property alias navExpanded: session.navExpanded

    readonly property bool initialOpeningComplete: panes.initialOpeningComplete
    readonly property Session session: Session {
        id: session

        root: root
    }

    signal close

    implicitWidth: Math.min(screen.width * 0.8, implicitHeight * Tokens.sizes.controlCenter.ratio)
    implicitHeight: Math.min(screen.height * 0.78, 1180)

    GridLayout {
        anchors.fill: parent

        rowSpacing: 0
        columnSpacing: 0
        rows: root.floating ? 2 : 1
        columns: 2

        Loader {
            Layout.fillWidth: true
            Layout.columnSpan: 2

            asynchronous: true
            active: root.floating
            visible: active

            sourceComponent: WindowTitle {
                screen: root.screen
                session: root.session
            }
        }

        StyledRect {
            Layout.fillHeight: true

            topLeftRadius: root.rounding
            bottomLeftRadius: root.rounding
            implicitWidth: navRail.implicitWidth
            color: Colours.tPalette.m3surfaceContainer

            NavRail {
                id: navRail

                anchors.fill: parent
                screen: root.screen
                session: root.session
                initialOpeningComplete: root.initialOpeningComplete
            }
        }

        Panes {
            id: panes

            Layout.fillWidth: true
            Layout.fillHeight: true

            topRightRadius: root.rounding
            bottomRightRadius: root.rounding
            session: root.session
        }
    }
}
