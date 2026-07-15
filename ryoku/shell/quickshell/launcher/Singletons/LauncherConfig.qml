pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Launcher knobs the Hub's App Launcher page edits, kept in
// ~/.config/ryoku/launcher.json and watched, so a save retunes the palette the
// next time it opens. Defaults here are canonical; the Hub mirrors them for
// reset-to-default and seeds nothing of its own.
Singleton {
    id: root

    property alias radius:       adapter.radius        // outer card corner, px
    property alias bgBlur:      adapter.bgBlur         // desktop blur behind the palette while open, px (0 = off)
    property alias weatherUnit:  adapter.weatherUnit   // auto (locale) | C | F
    property alias heroImage:    adapter.heroImage     // backdrop file, "" = shipped art
    property alias heroStrength: adapter.heroStrength  // backdrop opacity, 0..1
    property alias heroPosX:     adapter.heroPosX      // backdrop focal point, 0..1
    property alias heroPosY:     adapter.heroPosY
    property alias showWeather:  adapter.showWeather   // weather glance on the home card
    property alias showGreeting: adapter.showGreeting  // "Good morning" line

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property real radius: 16
            property int bgBlur: 12
            property string weatherUnit: "auto"
            property string heroImage: ""
            property real heroStrength: 0.6
            property real heroPosX: 0.5
            property real heroPosY: 0.5
            property bool showWeather: true
            property bool showGreeting: true
        }
    }

    // seed only on a genuine first run, so a slow or failed load can't overwrite
    // a present file with defaults.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
