import QtQuick
import Quickshell

ShellRoot {
    Loader {
        id: sceneLoader
        onLoaded: {
            console.log("BARSTYLE-PACKAGE-PROBE-PASS:" + Quickshell.env("BARSTYLE_ID"));
            Qt.callLater(Qt.quit);
        }
        onStatusChanged: {
            if (status === Loader.Error) {
                console.log("BARSTYLE-PACKAGE-PROBE-FAIL:" + Quickshell.env("BARSTYLE_ID"));
                Qt.callLater(Qt.quit);
            }
        }
    }

    Component.onCompleted: sceneLoader.setSource(
        Quickshell.env("BARSTYLE_SCENE"),
        {"modelData": Quickshell.screens.length > 0 ? Quickshell.screens[0] : null}
    )

    Timer {
        interval: 10000
        running: true
        onTriggered: {
            console.log("BARSTYLE-PACKAGE-PROBE-FAIL:timeout");
            Qt.quit();
        }
    }
}
