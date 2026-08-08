import QtQuick
import Quickshell.Services.Pipewire

// Default-sink volume / mute, read natively from PipeWire — event-driven, no
// subprocess. Replaces the old 3s `pactl` bash poll (the bar's most frequent
// idle fork). PipeWire pushes changes, so `volume`/`muted` update instantly.
//
// Public API kept identical so AudioWidget + VolumePanel need no changes:
//   volume (0-100), muted, refresh(), poll, interval.
// refresh()/poll/interval are now inert (event-driven, nothing to poll).
// portType was dropped — both consumers read it but never rendered it.
Item {
    id: audio

    property bool poll:     false   // inert (kept for API compat)
    property int  interval: 3000    // inert

    // the system default output; tracked live via PwObjectTracker below
    readonly property var sink: Pipewire.defaultAudioSink

    readonly property int  volume: (sink && sink.ready && sink.audio)
                                   ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted:  (sink && sink.ready && sink.audio)
                                   ? sink.audio.muted : false

    // kept so callers don't break; PipeWire is event-driven so there's nothing to do
    function refresh() {}

    // binding a node here makes Quickshell track its audio props (volume/mute) live
    PwObjectTracker { objects: audio.sink ? [audio.sink] : [] }
}
