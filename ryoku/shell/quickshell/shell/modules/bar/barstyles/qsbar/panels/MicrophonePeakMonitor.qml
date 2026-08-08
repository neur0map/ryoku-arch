import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    property bool panelOpen: false
    property bool muted: false
    readonly property real peak: monitor.peak

    visible: false

    PwNodePeakMonitor {
        id: monitor
        node: Pipewire.defaultAudioSource
        enabled: root.panelOpen && !root.muted && node !== null
    }
}
