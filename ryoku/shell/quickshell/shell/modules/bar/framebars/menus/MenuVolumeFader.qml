import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

HFader {
    id: root

    required property bool open

    icon: "speaker"
    lit: root.open
    value: Audio.sink ? Audio.sink.audio.volume : 0
    muted: Audio.sink ? Audio.sink.audio.muted : false
    valueLabel: !Audio.sink ? "" : (Audio.sink.audio.muted ? qsTr("off") : Math.round(Audio.sink.audio.volume * 100) + "%")
    peakNode: Audio.sink
    peakEnabled: root.open && !!Audio.sink
    onMoved: v => { if (Audio.sink) Audio.sink.audio.volume = v; }
    onIconTapped: { if (Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
}
