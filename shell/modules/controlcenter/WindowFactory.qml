pragma Singleton

import QtQuick
import Quickshell
import qs.components
import qs.services

Singleton {
    id: root

    property var currentWindow: null

    function open(parent: var, props: var): void {
        if (currentWindow) {
            currentWindow.visible = true;
            if (currentWindow.requestActivate)
                currentWindow.requestActivate();
            return;
        }

        currentWindow = controlCenter.createObject(parent ?? dummy, props ?? {});
    }

    function close(): void {
        if (!currentWindow)
            return;

        const win = currentWindow;
        currentWindow = null;
        win.destroy();
    }

    function toggle(parent: var, props: var): void {
        if (currentWindow)
            close();
        else
            open(parent, props);
    }

    function create(parent: var, props: var): void {
        open(parent, props);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: controlCenter

        FloatingWindow {
            id: win

            property alias active: cc.active
            property alias navExpanded: cc.navExpanded

            color: Colours.tPalette.m3surface

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            Component.onDestruction: {
                if (root.currentWindow === win)
                    root.currentWindow = null;
            }

            implicitWidth: cc.implicitWidth
            implicitHeight: cc.implicitHeight

            minimumSize.width: implicitWidth
            minimumSize.height: implicitHeight
            maximumSize.width: implicitWidth
            maximumSize.height: implicitHeight

            title: qsTr("Ryoku Settings - %1").arg(cc.active.slice(0, 1).toUpperCase() + cc.active.slice(1))

            ControlCenter {
                id: cc

                anchors.fill: parent
                screen: win.screen
                onClose: win.destroy()
                floating: true
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
