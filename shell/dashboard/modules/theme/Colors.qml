pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.dashboard.config
import qs.services

FileView {
    id: colors
    // QUICKSHELL-GIT: path: Quickshell.cachePath("colors.json")
    path: Quickshell.env("HOME") + "/.cache/ryoku/dashboard/colors.json"
    preload: true
    watchChanges: true
    onFileChanged: {
        reload();
        generationTimer.restart();
    }

    property Connections oledWatcher: Connections {
        target: Config
        function onOledModeChanged() {
            generationTimer.restart();
        }
    }

    property Connections themeWatcher: Connections {
        target: Config.loader
        function onFileChanged() {
            generationTimer.restart();
        }
    }

    property QtCtGenerator qtCtGenerator: QtCtGenerator {
        id: qtCtGenerator
    }

    property GtkGenerator gtkGenerator: GtkGenerator {
        id: gtkGenerator
    }

    property PywalGenerator pywalGenerator: PywalGenerator {
        id: pywalGenerator
    }

    property KittyGenerator kittyGenerator: KittyGenerator {
        id: kittyGenerator
    }

    property NvChadGenerator nvChadGenerator: NvChadGenerator {
        id: nvChadGenerator
    }

    property DiscordGenerator discordGenerator: DiscordGenerator {
        id: discordGenerator
    }

    property Timer generationTimer: Timer {
        id: generationTimer
        interval: 100
        repeat: false
        onTriggered: {
            qtCtGenerator.generate(colors);
            gtkGenerator.generate(colors);
            pywalGenerator.generate(colors);
            kittyGenerator.generate(colors);
            nvChadGenerator.generate(colors);
            discordGenerator.generate(colors);
        }
    }

    adapter: JsonAdapter {
        property color background: "#1a1111"
        property color blue: "#cebdfe"
        property color blueContainer: "#4c3e76"
        property color blueSource: "#0000ff"
        property color blueValue: "#0000ff"
        property color cyan: "#84d5c4"
        property color cyanContainer: "#005045"
        property color cyanSource: "#00ffff"
        property color cyanValue: "#00ffff"
        property color error: "#ffb4ab"
        property color errorContainer: "#93000a"
        property color green: "#b7d085"
        property color greenContainer: "#3a4d10"
        property color greenSource: "#00ff00"
        property color greenValue: "#00ff00"
        property color inverseOnSurface: "#382e2d"
        property color inversePrimary: "#904a46"
        property color inverseSurface: "#f1dedd"
        property color lightBlue: "#cebdfe"
        property color lightCyan: "#84d5c4"
        property color lightGreen: "#b7d085"
        property color lightMagenta: "#fcb0d5"
        property color lightRed: "#ffb4ab"
        property color lightYellow: "#dec56e"
        property color magenta: "#fcb0d5"
        property color magentaContainer: "#6c3353"
        property color magentaSource: "#ff00ff"
        property color magentaValue: "#ff00ff"
        property color overBackground: "#f1dedd"
        property color overBlue: "#35275e"
        property color overBlueContainer: "#e8ddff"
        property color overCyan: "#00382f"
        property color overCyanContainer: "#9ff2e0"
        property color overError: "#690005"
        property color overErrorContainer: "#ffdad6"
        property color overGreen: "#253600"
        property color overGreenContainer: "#d3ec9e"
        property color overMagenta: "#521d3c"
        property color overMagentaContainer: "#ffd8e8"
        property color overPrimary: "#571d1c"
        property color overPrimaryContainer: "#ffdad7"
        property color overPrimaryFixed: "#3b0809"
        property color overPrimaryFixedVariant: "#733331"
        property color overRed: "#561e19"
        property color overRedContainer: "#ffdad6"
        property color overSecondary: "#442928"
        property color overSecondaryContainer: "#ffdad7"
        property color overSecondaryFixed: "#2c1514"
        property color overSecondaryFixedVariant: "#5d3f3d"
        property color overSurface: "#f1dedd"
        property color overSurfaceVariant: "#d8c2c0"
        property color overTertiary: "#402d04"
        property color overTertiaryContainer: "#ffdea7"
        property color overTertiaryFixed: "#271900"
        property color overTertiaryFixedVariant: "#594319"
        property color overWhite: "#00363d"
        property color overWhiteContainer: "#9eeffd"
        property color overYellow: "#3b2f00"
        property color overYellowContainer: "#fce186"
        property color outline: "#a08c8b"
        property color outlineVariant: "#534342"
        property color primary: "#ffb3ae"
        property color primaryContainer: "#733331"
        property color primaryFixed: "#ffdad7"
        property color primaryFixedDim: "#ffb3ae"
        property color red: "#ffb4ab"
        property color redContainer: "#73332e"
        property color redSource: "#ff0000"
        property color redValue: "#ff0000"
        property color scrim: "#000000"
        property color secondary: "#e7bdb9"
        property color secondaryContainer: "#5d3f3d"
        property color secondaryFixed: "#ffdad7"
        property color secondaryFixedDim: "#e7bdb9"
        property color shadow: "#000000"
        property color surface: "#1a1111"
        property color surfaceBright: "#423736"
        property color surfaceContainer: "#271d1d"
        property color surfaceContainerHigh: "#322827"
        property color surfaceContainerHighest: "#3d3231"
        property color surfaceContainerLow: "#231919"
        property color surfaceContainerLowest: "#140c0c"
        property color surfaceDim: "#1a1111"
        property color surfaceTint: "#ffb3ae"
        property color surfaceVariant: "#534342"
        property color tertiary: "#e2c28c"
        property color tertiaryContainer: "#594319"
        property color tertiaryFixed: "#ffdea7"
        property color tertiaryFixedDim: "#e2c28c"
        property color white: "#82d3e0"
        property color whiteContainer: "#004f58"
        property color whiteSource: "#ffffff"
        property color whiteValue: "#ffffff"
        property color yellow: "#dec56e"
        property color yellowContainer: "#554500"
        property color yellowSource: "#ffff00"
        property color yellowValue: "#ffff00"
        property color sourceColor: "#7f2424"
    }

    // RYOKU: exposed colours are sourced from ryoku's live scheme singleton
    // (qs.services Colours.palette.m3*), the single palette source (scheme.json).
    // The adapter/JsonAdapter + colors.json FileView above are kept ONLY to feed
    // the external-app theme generators (qtct/gtk/pywal/kitty/nvchad/discord).
    // Named accents with no M3 equivalent (blue/cyan/magenta/white + their
    // *Source/*Value/light* variants) keep the adapter defaults; ryoku has no
    // equivalent for them and they're used by niche widgets.
    property color background: Config.oledMode ? "#000000" : Colours.palette.m3background

    property color surface: Colours.palette.m3surface
    property color surfaceBright: Colours.palette.m3surfaceBright
    property color surfaceContainer: Colours.palette.m3surfaceContainer
    property color surfaceContainerHigh: Colours.palette.m3surfaceContainerHigh
    property color surfaceContainerHighest: Colours.palette.m3surfaceContainerHighest
    property color surfaceContainerLow: Colours.palette.m3surfaceContainerLow
    property color surfaceContainerLowest: Colours.palette.m3surfaceContainerLowest
    property color surfaceDim: Colours.palette.m3surfaceDim
    property color surfaceTint: Colours.palette.m3surfaceTint
    property color surfaceVariant: Colours.palette.m3surfaceVariant

    property color blue: adapter.blue
    property color blueContainer: adapter.blueContainer
    property color blueSource: adapter.blueSource
    property color blueValue: adapter.blueValue
    property color cyan: adapter.cyan
    property color cyanContainer: adapter.cyanContainer
    property color cyanSource: adapter.cyanSource
    property color cyanValue: adapter.cyanValue
    property color error: Colours.palette.m3error
    property color errorContainer: Colours.palette.m3errorContainer
    property color green: Colours.palette.m3success
    property color greenContainer: Colours.palette.m3successContainer
    property color greenSource: adapter.greenSource
    property color greenValue: adapter.greenValue
    property color inverseOnSurface: Colours.palette.m3inverseOnSurface
    property color inversePrimary: Colours.palette.m3inversePrimary
    property color inverseSurface: Colours.palette.m3inverseSurface
    property color lightBlue: adapter.lightBlue
    property color lightCyan: adapter.lightCyan
    property color lightGreen: adapter.lightGreen
    property color lightMagenta: adapter.lightMagenta
    property color lightRed: adapter.lightRed
    property color lightYellow: adapter.lightYellow
    property color magenta: adapter.magenta
    property color magentaContainer: adapter.magentaContainer
    property color magentaSource: adapter.magentaSource
    property color magentaValue: adapter.magentaValue
    property color overBackground: Colours.palette.m3onBackground
    property color overBlue: adapter.overBlue
    property color overBlueContainer: adapter.overBlueContainer
    property color overCyan: adapter.overCyan
    property color overCyanContainer: adapter.overCyanContainer
    property color overError: Colours.palette.m3onError
    property color overErrorContainer: Colours.palette.m3onErrorContainer
    property color overGreen: Colours.palette.m3onSuccess
    property color overGreenContainer: Colours.palette.m3onSuccessContainer
    property color overMagenta: adapter.overMagenta
    property color overMagentaContainer: adapter.overMagentaContainer
    property color overPrimary: Colours.palette.m3onPrimary
    property color overPrimaryContainer: Colours.palette.m3onPrimaryContainer
    property color overPrimaryFixed: Colours.palette.m3onPrimaryFixed
    property color overPrimaryFixedVariant: Colours.palette.m3onPrimaryFixedVariant
    property color overRed: Colours.palette.m3onError
    property color overRedContainer: adapter.overRedContainer
    property color overSecondary: Colours.palette.m3onSecondary
    property color overSecondaryContainer: Colours.palette.m3onSecondaryContainer
    property color overSecondaryFixed: Colours.palette.m3onSecondaryFixed
    property color overSecondaryFixedVariant: Colours.palette.m3onSecondaryFixedVariant
    property color overSurface: Colours.palette.m3onSurface
    property color overSurfaceVariant: Colours.palette.m3onSurfaceVariant
    property color overTertiary: Colours.palette.m3onTertiary
    property color overTertiaryContainer: Colours.palette.m3onTertiaryContainer
    property color overTertiaryFixed: Colours.palette.m3onTertiaryFixed
    property color overTertiaryFixedVariant: Colours.palette.m3onTertiaryFixedVariant
    property color overWhite: adapter.overWhite
    property color overWhiteContainer: adapter.overWhiteContainer
    property color overYellow: Colours.palette.m3onTertiary
    property color overYellowContainer: adapter.overYellowContainer
    property color outline: Colours.palette.m3outline
    property color outlineVariant: Colours.palette.m3outlineVariant
    property color primary: Colours.palette.m3primary
    property color primaryContainer: Colours.palette.m3primaryContainer
    property color primaryFixed: Colours.palette.m3primaryFixed
    property color primaryFixedDim: Colours.palette.m3primaryFixedDim
    property color red: Colours.palette.m3error
    property color redContainer: Colours.palette.m3errorContainer
    property color redSource: adapter.redSource
    property color redValue: adapter.redValue
    property color scrim: Colours.palette.m3scrim
    property color secondary: Colours.palette.m3secondary
    property color secondaryContainer: Colours.palette.m3secondaryContainer
    property color secondaryFixed: Colours.palette.m3secondaryFixed
    property color secondaryFixedDim: Colours.palette.m3secondaryFixedDim
    property color shadow: Colours.palette.m3shadow
    property color tertiary: Colours.palette.m3tertiary
    property color tertiaryContainer: Colours.palette.m3tertiaryContainer
    property color tertiaryFixed: Colours.palette.m3tertiaryFixed
    property color tertiaryFixedDim: Colours.palette.m3tertiaryFixedDim
    property color white: adapter.white
    property color whiteContainer: adapter.whiteContainer
    property color whiteSource: adapter.whiteSource
    property color whiteValue: adapter.whiteValue
    property color yellow: Colours.palette.m3tertiary
    property color yellowContainer: adapter.yellowContainer
    property color yellowSource: adapter.yellowSource
    property color yellowValue: adapter.yellowValue
    property color sourceColor: adapter.sourceColor

    property color criticalText: "#FF6B08"
    property color criticalRed: "#FF0028"

    property color warning: Colours.palette.m3tertiary
    property color success: Colours.palette.m3success

    readonly property var availableColorNames: ["background", "surface", "surfaceBright", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "surfaceDim", "surfaceTint", "surfaceVariant", "primary", "primaryContainer", "primaryFixed", "primaryFixedDim", "secondary", "secondaryContainer", "secondaryFixed", "secondaryFixedDim", "tertiary", "tertiaryContainer", "tertiaryFixed", "tertiaryFixedDim", "error", "errorContainer", "overBackground", "overSurface", "overSurfaceVariant", "overPrimary", "overPrimaryContainer", "overPrimaryFixed", "overPrimaryFixedVariant", "overSecondary", "overSecondaryContainer", "overSecondaryFixed", "overSecondaryFixedVariant", "overTertiary", "overTertiaryContainer", "overTertiaryFixed", "overTertiaryFixedVariant", "overError", "overErrorContainer", "outline", "outlineVariant", "inversePrimary", "inverseSurface", "inverseOnSurface", "shadow", "scrim", "blue", "blueContainer", "overBlue", "overBlueContainer", "lightBlue", "cyan", "cyanContainer", "overCyan", "overCyanContainer", "lightCyan", "green", "greenContainer", "overGreen", "overGreenContainer", "lightGreen", "magenta", "magentaContainer", "overMagenta", "overMagentaContainer", "lightMagenta", "red", "redContainer", "overRed", "overRedContainer", "lightRed", "yellow", "yellowContainer", "overYellow", "overYellowContainer", "lightYellow", "white", "whiteContainer", "overWhite", "overWhiteContainer"]
}
