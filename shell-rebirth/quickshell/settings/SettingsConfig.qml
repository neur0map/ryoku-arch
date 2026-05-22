pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property alias matugenScheme: settingsAdapter.matugenScheme
    property alias matugenTheme: settingsAdapter.matugenTheme
    property alias musicVisOn: settingsAdapter.musicVisOn
    property alias firstColor: settingsAdapter.firstColor
    property alias secondColor: settingsAdapter.secondColor
    property alias thirdColor: settingsAdapter.thirdColor
    property alias pinnedApps: settingsAdapter.pinnedApps
    property alias dock: settingsAdapter.dock
    property alias dockAutoHide: settingsAdapter.dockAutoHide
    property alias dockMusicPlayer: settingsAdapter.dockMusicPlayer

    // Wallhaven online wallpaper settings
    property alias wallhavenApiKey: settingsAdapter.wallhavenApiKey
    property alias wallhavenCategories: settingsAdapter.wallhavenCategories
    property alias wallhavenPurity: settingsAdapter.wallhavenPurity
    property alias wallhavenSorting: settingsAdapter.wallhavenSorting
    property alias wallhavenOrder: settingsAdapter.wallhavenOrder
    property alias wallhavenTopRange: settingsAdapter.wallhavenTopRange
    property alias wallhavenAtleast: settingsAdapter.wallhavenAtleast
    property alias wallhavenRatios: settingsAdapter.wallhavenRatios

    property alias appGrid: settingsAdapter.appGrid


    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.reload()
    }

    FileView {

        id: settingsFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/settings.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeTimer.restart()
            }
        }

        adapter: JsonAdapter {
            id: settingsAdapter
            property string matugenScheme: "scheme-content"
            property string matugenTheme: "Light"
            property bool musicVisOn: true
            property string firstColor: "#ffffff"
            property string secondColor: "#ffffff"
            property string thirdColor: "#fffff"
            property list<string> pinnedApps: []
            property bool dock: true
            property bool dockAutoHide: true
            property bool dockMusicPlayer: true

            // Wallhaven params
            property string wallhavenApiKey: "ugj2klyucx6IylJNxGQYu6sHyztDaav2"
            property string wallhavenCategories: "111"
            property string wallhavenPurity: "100"
            property string wallhavenSorting: "toplist"
            property string wallhavenOrder: "desc"
            property string wallhavenTopRange: "1M"
            property string wallhavenAtleast: ""
            property string wallhavenRatios: ""

            property bool appGrid: false
        }
    }
}