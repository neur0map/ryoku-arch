pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services as Services

Singleton {
    PwObjectTracker {
        objects: [
            Pipewire.defaultAudioSource,
            Pipewire.defaultAudioSink,
            Pipewire.nodes,
            Pipewire.links
        ]
    }

    property var sinks: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio)
    property PwNode defaultSink: Pipewire.defaultAudioSink

    property var sources: Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && node.audio)
    property PwNode defaultSource: Pipewire.defaultAudioSource

    property real volume: (defaultSink?.audio?.volume > 1 ? 1 : defaultSink?.audio?.volume) ?? 0
    property bool muted: defaultSink?.audio?.muted ?? false

    Connections {
        id: audioConn
        target: defaultSink && defaultSink.audio ? defaultSink.audio : null

        function onVolumeChanged() {
            let vol = Math.min(defaultSink.audio.volume * 100, 100)  // Clamp to 100
            Services.Osd.show("volume", vol)
        }

        function onMutedChanged() {
            let vol = defaultSink.audio.muted ? 0 : Math.min(defaultSink.audio.volume * 100, 100)
            Services.Osd.show("volume", vol)
        }
    }

    function setVolume(to: real): void {
        if (defaultSink?.ready && defaultSink?.audio) {
            defaultSink.audio.muted = false;
            let val = Math.max(0, Math.min(1, to));
            defaultSink.audio.volume = val
            Services.Osd.show("volume", val * 100)
        }
    }

    function setSourceVolume(to: real): void {
        if (defaultSource?.ready && defaultSource?.audio) {
            defaultSource.audio.muted = false;
            let val = Math.max(0, Math.min(1, to));
            defaultSource.audio.volume = val
            Services.Osd.show("volume", val * 100)
        }
    }

    function setDefaultSink(sink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = sink;
    }

    function setDefaultSource(source: PwNode): void {
        Pipewire.preferredDefaultAudioSource = source;
    }

    function init() {
    }
}