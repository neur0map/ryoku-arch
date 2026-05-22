import QtQuick
import Quickshell
import qs.modules.network
import qs.modules.control
import qs.modules.calendar
import qs.modules.media
import qs.modules.bar
import qs.modules.system
import qs.modules.switcher
import Quickshell.Io
import qs.services as Services
import qs.components
import qs.Osd
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.quotes
import qs.modules.launcher
import qs.modules.wallpaper
import qs.modules.manga
import qs.modules.novel
import qs.modules.anime
import qs.aikira

ShellRoot {
    id: root
    NotificationToasts {}
    CalendarWindow {}
    RandomQuote{}
    PanelWindow {
        focusable: true
        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
    }
    WindowSwitcher{}
    Visualizer {
        id: visBottom
        anchorBottom: true
        visible: false
    }
    Visualizer {
        id: visTop
        anchorBottom: false
        visible: visBottom.visible
    }
    PanelWindow {
        id: rootPanel
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: screen.height
        implicitWidth: screen.width
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        focusable: true

        Loader {
            id: mediaPanelLoader
            active: false
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: MediaPanel {
                id: mediaPanel
            }
            focus: true
        }
        GhPopout {
            id: ghPopout
            anchors {
                right: parent.right
                bottom: parent.bottom
            }
        }
        SystemPanel {
            id: systemPanel
        }
        WallhavenWrapper{
            id: wallhavenWrapper
        }
        Loader {
            id: networkPanelLoader
            active: false
            anchors.fill: parent
            sourceComponent: NetworkPanel {
                id: networkPanel
            }
        }

        OsdWindow {}

        PanelWindow{
            implicitHeight: 42
            implicitWidth: 0
            anchors {
                top: true
            }
            color: "transparent"
            mask: rootPanel.mask
        }

        TopBar{
            id: topBar
        }
        NotesDrawer{
            id: notesDrawer
        }

        MouseArea {
            id: notesDrawerTrigger
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: 2
            z: 100
            width: 900

            onClicked: {
                notesDrawer.opened = !notesDrawer.opened
            }

            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }

        MouseArea {
            id: githubTrigger
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 2
            z: 100
            height: 500

            onEntered: {
                ghPopout.opened = !ghPopout.opened
            }

            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }

        LauncherWindow{
            id: launcherWindow
        }

        MouseArea {
            id: launcherTrigger
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 2
            z: 100
            height: 600

            onEntered: {
                launcherWindow.toggle()
            }

            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }
        Wallpaper{
            id: wallpaper
        }

        Loader {
            active: false
            id: controlCenterLoader
            anchors.fill: parent
            sourceComponent: ControlCenter {
                id: controlCenter
            }
            focus: true
        }
        Loader {
            active: false
            id: chatLoader
            anchors.centerIn: parent
            sourceComponent: OllamaChat{
                id: ollamaChat
            }
            focus: true
        }
        Loader {
            active: false
            id: mangaLoader
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            sourceComponent: MangaReader{
                id: mangaReader
            }
        }
        Loader {
            active: false
            id: novelLoader
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            sourceComponent: NovelReader{
                id: novelReaderReader
            }
        }
        Loader {
            active: false
            id: animeLoader
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            sourceComponent: AnimePanel{
                id: animePlayer
            }
        }

        Loader {
            active: false
            id: aikiraLoader
            anchors.centerIn: parent
            sourceComponent: Aikira {
                id: aikiraChat
            }
            focus: true
        }

        ClipboardManager {
            id: clipboardManager
        }

        PowerMenu {
            id: powerMenu
        }

        AvatarPicker {
            id: avatarPicker
        }

        property bool altHeld: false

        mask: Region{
            Region{
                item: mediaPanelLoader.active ? mediaPanelLoader : null
            }
            Region{
                item: systemPanel
            }
            Region{
                item: topBar
            }
            Region {
                item: networkPanelLoader.item && networkPanelLoader.item.visible ? networkPanelLoader.item : null
            }
            Region{
                item: notesDrawer.opened ? notesDrawer : null
            }
            Region{
                item: notesDrawerTrigger
            }
            Region{
                item: controlCenterLoader.item && controlCenterLoader.item.visible ? controlCenterLoader.item : null
            }
            Region {
                item: githubTrigger
            }
            Region {
                item: ghPopout
            }
            Region{
                item: launcherTrigger
            }
            Region {
                item: launcherWindow.isOpen ? launcherWindow : null
            }
            Region{
                item: wallpaper.visible ? wallpaper : null
            }
            Region{
                item: chatLoader.active ? chatLoader : null
            }
            Region{
                item: mangaLoader.item.visible ? mangaLoader.item : null
            }
            Region{
                item: novelLoader.item.visible ? novelLoader.item : null
            }
            Region{
                item: animeLoader.item.visible ? animeLoader.item : null
            }
            Region {
                item: aikiraLoader.active ? aikiraLoader : null
            }
            Region {
                item: clipboardManager.visible ? clipboardManager : null
            }
            Region {
                item: powerMenu.visible ? powerMenu : null
            }
            Region {
                item: avatarPicker
            }
        }
    }

    Connections {
        target: mediaPanelLoader.item
        function onOpenedChanged() {
            if (!mediaPanelLoader.item.opened) {
                closeTimer.start()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 600
        onTriggered: mediaPanelLoader.active = false
    }

    Timer {
        id: closeChatTimer
        interval: 600
        onTriggered: chatLoader.active = false
    }

    Connections {
        target: chatLoader.item
        function onVisibleChanged() {
            if (chatLoader.item && !chatLoader.item.visible) {
                closeChatTimer.start()
            }
        }
    }

    Timer {
        id: closeMangaTimer
        interval: 600
        onTriggered: mangaLoader.active = false
    }

    Connections {
        target: mangaLoader.item
        function onVisibleChanged() {
            if (mangaLoader.item && !mangaLoader.item.visible) {
                closeMangaTimer.start()
            }
        }
    }

    Timer {
        id: closeNovelTimer
        interval: 600
        onTriggered: novelLoader.active = false
    }

    Connections {
        target: novelLoader.item
        function onVisibleChanged() {
            if (novelLoader.item && !novelLoader.item.visible) {
                closeNovelTimer.start()
            }
        }
    }

    Timer {
        id: closeAnimeTimer
        interval: 600
        onTriggered: animeLoader.active = false
    }

    Connections {
        target: animeLoader.item
        function onVisibleChanged() {
            if (animeLoader.item && !animeLoader.item.visible) {
                closeAnimeTimer.start()
            }
        }
    }

    Timer {
        id: closeNetworkTimer
        interval: 600
        onTriggered: networkPanelLoader.active = false
    }

    Connections {
        target: networkPanelLoader.item
        function onOpenedChanged() {
            if (networkPanelLoader.item && !networkPanelLoader.item.opened) {
                closeNetworkTimer.start()
            }
        }
    }

    Timer {
        id: closeControlCenterTimer
        interval: 600
        onTriggered: controlCenterLoader.active = false
    }

    Connections {
        target: controlCenterLoader.item
        function onOpenedChanged() {
            if (controlCenterLoader.item && !controlCenterLoader.item.opened) {
                closeControlCenterTimer.start()
            }
        }
    }

    IpcHandler {
        target: "mediaPanel"

        function toggle(): void {
            if (!mediaPanelLoader.active) {
                mediaPanelLoader.active = true
                mediaPanelLoader.item.opened = true
            } else {
                mediaPanelLoader.item.opened = !mediaPanelLoader.item.opened
            }
        }
    }

    IpcHandler {
        target: "mangaReader"

        function toggle(): void {
            if (!mangaLoader.active) {
                mangaLoader.active = true
                mangaLoader.item.visible = true
            } else {
                mangaLoader.item.visible = !mangaLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "novelReader"

        function toggle(): void {
            if (!novelLoader.active) {
                novelLoader.active = true
                novelLoader.item.visible = true
            } else {
                novelLoader.item.visible = !novelLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "animePlayer"

        function toggle(): void {
            if (!animeLoader.active) {
                animeLoader.active = true
                animeLoader.item.visible = true
            } else {
                animeLoader.item.visible = !animeLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "networkPanel"

        function changeVisible(tab: string): void {
            if (!networkPanelLoader.active)
                networkPanelLoader.active = true

            const panel = networkPanelLoader.item
            if (!panel)
                return

            if (panel.opened) {
                panel.opened = false
                return
            }

            if (tab === "wifi")
                panel.currentTab = 0
            else if (tab === "bluetooth")
                panel.currentTab = 1

            if (tab !== undefined)
                panel.opened = true
            else
                panel.opened = !panel.opened
        }
    }

    IpcHandler {
        target: "controlCenter"
        function changeVisible(): void {
            if (!controlCenterLoader.active) {
                controlCenterLoader.active = true
                controlCenterLoader.item.opened = true
            } else {
                controlCenterLoader.item.opened = !controlCenterLoader.item.opened
            }
        }
    }

    IpcHandler {
        target: "ollamaChat"
        function changeVisible(): void {
            if (!chatLoader.active) {
                chatLoader.active = true
                chatLoader.item.visible = true
            } else {
                chatLoader.item.visible = !chatLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "visBottom"

        function toggle() {
            visBottom.visible = !visBottom.visible
        }
    }

    IpcHandler {
        target: "launcherWindow"

        function toggle() {
            launcherWindow.toggle()
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() {
            wallpaper.visible = !wallpaper.visible
        }
    }

    Timer {
        id: closeWindowSwitcherTimer
        interval: 300
        onTriggered: windowSwitcherLoader.active = false
    }

    IpcHandler {
        target: "clipboardManager"
        function changeVisible(): void {
            if (!clipboardManager.visible) {
                clipboardManager.open()
            } else {
                clipboardManager.close()
            }
        }
    }

    IpcHandler {
        target: "powerMenu"
        function toggle(): void {
            if (!powerMenu.visible) {
                powerMenu.open()
            } else {
                powerMenu.close()
            }
        }
    }

    IpcHandler {
        target: "avatarPicker"
        function toggle(): void {
            if (!avatarPicker.opened) {
                avatarPicker.open()
            } else {
                avatarPicker.close()
            }
        }
    }

    IpcHandler {
        target: "aikiraChat"
        function changeVisible(): void {
            if (!aikiraLoader.active) {
                aikiraLoader.active = true
                aikiraLoader.item.visible = true
            } else {
                aikiraLoader.item.visible = !aikiraLoader.item.visible
            }
        }
    }

    Timer {
        id: closeAikiraTimer
        interval: 600
        onTriggered: aikiraLoader.active = false
    }

    Connections {
        target: aikiraLoader.item
        function onVisibleChanged() {
            if (aikiraLoader.item && !aikiraLoader.item.visible) {
                closeAikiraTimer.start()
            }
        }
    }

}