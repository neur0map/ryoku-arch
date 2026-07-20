pragma Singleton
import QtQuick
import Quickshell

// The ryolayer widget registry: every tool the layer can host, with its file
// and size envelope. Instances (which screen, where, pinned) live in
// ryolayer.json via Config; this list is the shipped vocabulary.
Singleton {
    readonly property var widgets: [
        {
            id: "music",
            title: "SOUND / OUT",
            kanji: "\u97f3",
            source: "widgets/music/MusicWidget.qml",
            defW: 440, defH: 250,
            minW: 360, minH: 210,
            maxW: 640, maxH: 760
        },
        {
            id: "mic",
            title: "SOUND / IN",
            kanji: "\u58f0",
            source: "widgets/mic/MicWidget.qml",
            defW: 400, defH: 300,
            minW: 340, minH: 240,
            maxW: 600, maxH: 640
        },
        {
            id: "notes",
            title: "NOTES",
            kanji: "\u8a18",
            source: "widgets/notes/NotesWidget.qml",
            defW: 380, defH: 430,
            minW: 300, minH: 280,
            maxW: 640, maxH: 900
        },
        {
            id: "sys",
            title: "SYSTEM",
            kanji: "\u76e3",
            source: "widgets/sys/SysWidget.qml",
            defW: 440, defH: 380,
            minW: 340, minH: 260,
            maxW: 720, maxH: 900
        }
    ]

    function byId(id) {
        for (var i = 0; i < widgets.length; i++)
            if (widgets[i].id === id)
                return widgets[i];
        return null;
    }
}
