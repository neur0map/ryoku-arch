import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../colors" as ColorsModule
import qs.components

Scope {
    id: root
    property var onQuoteFetched: (text) => rootText = text
    property var quoteApiType: "text"
    property var quotePath: ""
    property var rootText: "Loading...."

    Process {
        id: fetchGetProcess
        command: ["curl", "https://icanhazdadjoke.com/"]
        property var callback: [(text) => {}, ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                if (fetchGetProcess.callback) {
                    if (root.quoteApiType === "json") {
                        const json = JSON.parse(text)
                        const path = fetchGetProcess.callback[1]
                        fetchGetProcess.callback[0](jsonPath(json, path))
                    } else {
                        fetchGetProcess.callback[0](text)
                    }
                }
            }
        }
    }

    function fetchGetQuote(path, page, callback) {
        fetchGetProcess.exec({command: ["curl", "https://icanhazdadjoke.com/"]})
        fetchGetProcess.callback = [callback, path]
    }

    Timer {
        id: periodicRefetchTimer
        interval: 10*60*1000 
        running: true
        repeat: true
        onTriggered: {
            fetchGetQuote(root.quotePath, root.quotePage, root.onQuoteFetched)
        }
        Component.onCompleted: {
            fetchGetQuote(root.quotePath, root.quotePage, root.onQuoteFetched)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            WlrLayershell.layer: WlrLayer.Background
            required property var modelData
            screen: modelData
            anchors {
                bottom: true
                left: true
            }
            implicitWidth: 500
            implicitHeight: 120
            color: "transparent"

            Popout {
                id: popout
                anchors.fill: parent
                alignment: 5
                radius: 20
                color: ColorsModule.Colors.background

                Text {
                    id: textElement
                    text: root.rootText
                    color: ColorsModule.Colors.on_surface
                    anchors.fill: parent
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}