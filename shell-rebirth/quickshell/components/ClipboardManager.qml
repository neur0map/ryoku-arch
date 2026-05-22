import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../colors" as ColorsModule

Item {
    id: root
    anchors.fill: parent
    visible: false

    // 0 = Clipboard  1 = Emoji  2 = Kaomoji
    property int    currentTab: 0
    property string searchText: ""
    property string _clipBuf:   ""

    // ── File views ────────────────────────────────────────────────────────────

    FileView {
        id: emojiFile
        path: Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/files/emoji.json"
    }

    FileView {
        id: kaomojiFile
        path: Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/files/kaomoji.json"
    }

    readonly property var _emojiRaw: {
        const t = emojiFile.text()
        if (!t || !t.trim()) return {}
        try { return JSON.parse(t) } catch(e) { return {} }
    }

    readonly property var _kaoRaw: {
        const t = kaomojiFile.text()
        if (!t || !t.trim()) return []
        try { return JSON.parse(t) } catch(e) { return [] }
    }

    readonly property var emojiAllItems: {
        const out = []
        for (const emoji in _emojiRaw)
            out.push({ emoji: emoji, name: _emojiRaw[emoji].name, category: _emojiRaw[emoji].group })
        return out
    }

    readonly property var kaoAllItems: {
        const out = []
        for (const group of _kaoRaw)
            for (const cat of group.categories)
                for (const text of cat.emoticons)
                    out.push({ text: text, group: group.name, category: cat.name })
        return out
    }

    // ── Clipboard data ────────────────────────────────────────────────────────

    property var clipAllEntries: []
    property int _thumbGen: 0

    readonly property var clipFiltered: {
        const q = searchText.trim().toLowerCase()
        if (!q) return clipAllEntries
        return clipAllEntries.filter(e => e.preview.toLowerCase().includes(q))
    }

    readonly property var emojiFiltered: {
        const q = searchText.trim().toLowerCase()
        if (!q) return emojiAllItems
        return emojiAllItems.filter(e =>
            e.name.toLowerCase().includes(q) ||
            e.category.toLowerCase().includes(q) ||
            e.emoji === q
        )
    }

    readonly property var kaoFiltered: {
        const q = searchText.trim().toLowerCase()
        if (!q) return kaoAllItems
        return kaoAllItems.filter(e =>
            e.text.toLowerCase().includes(q) ||
            e.group.toLowerCase().includes(q) ||
            e.category.toLowerCase().includes(q)
        )
    }

    // ── Open / Close ──────────────────────────────────────────────────────────

    function open() {
        visible = true
        searchField.text = ""
        searchField.forceActiveFocus()
        panel.x = root.width
        scrim.opacity = 0
        openAnim.restart()
        _clipBuf = ""
        loadClipboard.running = true
    }

    function close() {
        closeAnim.restart()
    }

    // ── Processes ─────────────────────────────────────────────────────────────

    Process {
        id: loadClipboard
        command: ["cliphist", "list"]
        running: false
        stdout: SplitParser {
            onRead: line => { root._clipBuf += line + "\n" }
        }
        onExited: {
            const lines = root._clipBuf.split("\n").filter(l => l.trim() !== "")
            const entries = lines.map((line, idx) => {
                const tab     = line.indexOf("\t")
                const preview = tab === -1 ? line : line.substring(tab + 1).replace(/\s+/g, " ").trim()
                const isImg   = preview.startsWith("[[ binary data") || preview.startsWith("[[ img")
                return {
                    lineIdx:   idx + 1,
                    preview:   isImg ? "Image" : preview,
                    isImage:   isImg,
                    thumbPath: isImg ? "/tmp/qs_clip_thumb_" + (idx + 1) + ".png" : ""
                }
            })
            root.clipAllEntries = entries
            const imgs = entries.filter(e => e.isImage).slice(0, 20)
            if (imgs.length > 0) {
                const cmd = imgs.map(e =>
                    "cliphist list | sed -n '" + e.lineIdx + "p' | cliphist decode > " + e.thumbPath
                ).join(" & ")
                thumbDecoder.command = ["bash", "-c", cmd + " & wait"]
                thumbDecoder.running = true
            }
        }
    }

    Process {
        id: thumbDecoder
        running: false
        onExited: {
            root._thumbGen++
            const t = root.clipAllEntries
            root.clipAllEntries = []
            root.clipAllEntries = t
        }
    }

    Process { id: pasteProcess; running: false }
    Process { id: copyProcess;  running: false }
    Process {
        id: wipeProcess
        command: ["cliphist", "wipe"]
        running: false
        onExited: { root.clipAllEntries = []; root._clipBuf = "" }
    }

    function pasteClipEntry(entry) {
        if (!entry) return
        pasteProcess.command = ["bash", "-c",
            "cliphist list | sed -n '" + entry.lineIdx + "p' | cliphist decode | wl-copy"]
        pasteProcess.running = true
        root.close()
    }

    function copyText(text) {
        const esc = text.replace(/'/g, "'\\''")
        copyProcess.command = ["bash", "-c", "printf '%s' '" + esc + "' | wl-copy"]
        copyProcess.running = true
        root.close()
    }

    // ── Scrim ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: ColorsModule.Colors.scrim
        opacity: 0
        enabled: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; enabled: parent.enabled; onClicked: root.close() }
    }

    // ── Edge shadow ───────────────────────────────────────────────────────────

    Rectangle {
        anchors.top: panel.top
        anchors.bottom: panel.bottom
        anchors.right: panel.left
        width: 48
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
        }
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 420
        x: root.width   // starts off-screen; animated to root.width - width

        color: ColorsModule.Colors.surface_container_low
        enabled: scrim.opacity > 0.01

        // Left border
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: ColorsModule.Colors.outline_variant
            opacity: 0.6
        }

        // ── Animations ────────────────────────────────────────────────────────

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: scrim; property: "opacity"
                to: 0.45; duration: 280; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: panel; property: "x"
                to: root.width - panel.width; duration: 320; easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation {
                target: scrim; property: "opacity"
                to: 0; duration: 200; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panel; property: "x"
                to: root.width; duration: 260; easing.type: Easing.InCubic
            }
            onFinished: root.visible = false
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header ────────────────────────────────────────────────────────

            Item {
                Layout.fillWidth: true
                height: 60

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        text: "󰅍"
                        font.family: "Material Design Icons"
                        font.pixelSize: 20
                        color: ColorsModule.Colors.primary
                        opacity: 0.85
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: root.currentTab === 0 ? "Clipboard"
                            : root.currentTab === 1 ? "Emoji"
                            :                         "Kaomoji"
                        font.pixelSize: 16
                        font.weight: Font.SemiBold
                        color: ColorsModule.Colors.on_surface
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on text {}
                    }

                    // Wipe — clipboard tab only
                    Rectangle {
                        visible: root.currentTab === 0
                        width: 30; height: 30; radius: 15
                        color: wipeMA.containsMouse
                            ? ColorsModule.Colors.error_container : "transparent"
                        border.color: wipeMA.containsMouse
                            ? ColorsModule.Colors.error : ColorsModule.Colors.outline_variant
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color        { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰩺"
                            font.family: "Material Design Icons"
                            font.pixelSize: 15
                            color: wipeMA.containsMouse
                                ? ColorsModule.Colors.error
                                : ColorsModule.Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        MouseArea {
                            id: wipeMA; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: wipeProcess.running = true
                            ToolTip.visible: containsMouse
                            ToolTip.text: "Wipe clipboard history"
                            ToolTip.delay: 500
                        }
                    }

                    // Close
                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: closeHov.containsMouse
                            ? ColorsModule.Colors.surface_container_high : "transparent"
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "Material Design Icons"
                            font.pixelSize: 16
                            color: ColorsModule.Colors.on_surface_variant
                        }
                        MouseArea {
                            id: closeHov; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }

                // bottom separator
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 1
                    color: ColorsModule.Colors.outline_variant
                    opacity: 0.4
                }
            }

            // ── Tab bar ───────────────────────────────────────────────────────

            Item {
                Layout.fillWidth: true
                height: 46

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "Clipboard", icon: "󰅍", idx: 0 },
                            { label: "Emoji",     icon: "󰞅", idx: 1 },
                            { label: "Kaomoji",   icon: "󰙃", idx: 2 }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            property bool active: root.currentTab === modelData.idx

                            Layout.fillWidth: true
                            height: 34
                            radius: 10

                            color: active
                                ? ColorsModule.Colors.primary_container
                                : tabHov.containsMouse
                                    ? ColorsModule.Colors.surface_container
                                    : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.family: "Material Design Icons"
                                    font.pixelSize: 14
                                    color: active
                                        ? ColorsModule.Colors.on_primary_container
                                        : ColorsModule.Colors.on_surface_variant
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font.pixelSize: 12
                                    font.family: "Noto Sans"
                                    font.weight: active ? Font.SemiBold : Font.Normal
                                    color: active
                                        ? ColorsModule.Colors.on_primary_container
                                        : ColorsModule.Colors.on_surface_variant
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                id: tabHov; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentTab = modelData.idx
                                    searchField.text = ""
                                    searchField.forceActiveFocus()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 1
                    color: ColorsModule.Colors.outline_variant
                    opacity: 0.4
                }
            }

            // ── Search ────────────────────────────────────────────────────────

            Item {
                Layout.fillWidth: true
                height: 48

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: "󰍉"
                        font.family: "Material Design Icons"
                        font.pixelSize: 18
                        color: searchField.activeFocus
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.on_surface_variant
                        opacity: searchField.activeFocus ? 1 : 0.6
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color   { ColorAnimation  { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        placeholderText: root.currentTab === 0 ? "Search clipboard…"
                                       : root.currentTab === 1 ? "Search emoji…"
                                       :                         "Search kaomoji…"
                        font.pixelSize: 13
                        font.family: "Noto Sans"
                        color: ColorsModule.Colors.on_surface
                        placeholderTextColor: ColorsModule.Colors.on_surface_variant
                        background: Item {}
                        leftPadding: 0
                        onTextChanged: root.searchText = text
                        Keys.onEscapePressed: root.close()
                        Keys.onReturnPressed: {
                            if (root.currentTab === 0 && root.clipFiltered.length > 0)
                                root.pasteClipEntry(root.clipFiltered[Math.max(0, clipList.currentIndex)])
                            else if (root.currentTab === 1 && root.emojiFiltered.length > 0)
                                root.copyText(root.emojiFiltered[Math.max(0, emojiGrid.currentIndex)].emoji)
                            else if (root.currentTab === 2 && root.kaoFiltered.length > 0)
                                root.copyText(root.kaoFiltered[Math.max(0, kaoList.currentIndex)].text)
                        }
                        Keys.onDownPressed: {
                            if (root.currentTab === 0)      clipList.forceActiveFocus()
                            else if (root.currentTab === 1) emojiGrid.forceActiveFocus()
                            else                            kaoList.forceActiveFocus()
                        }
                    }

                    Rectangle {
                        visible: searchField.text.length > 0
                        width: 22; height: 22; radius: 11
                        color: clrHov.containsMouse
                            ? ColorsModule.Colors.surface_container_highest : "transparent"
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "󰅖"
                            font.family: "Material Design Icons"
                            font.pixelSize: 13
                            color: ColorsModule.Colors.on_surface_variant
                        }
                        MouseArea {
                            id: clrHov; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: searchField.text = ""
                        }
                    }
                }

                // focused underline
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 1
                    color: searchField.activeFocus
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.outline_variant
                    opacity: searchField.activeFocus ? 0.85 : 0.35
                    Behavior on color   { ColorAnimation  { duration: 180 } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }

            // ── Content ───────────────────────────────────────────────────────

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── Clipboard ─────────────────────────────────────────────────

                ListView {
                    id: clipList
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.bottomMargin: 6
                    visible: root.currentTab === 0
                    clip: true
                    spacing: 4
                    currentIndex: -1
                    model: root.clipFiltered

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 3; radius: 2
                            color: ColorsModule.Colors.outline
                            opacity: 0.6
                        }
                        background: Item {}
                    }

                    Keys.onReturnPressed:  { if (currentIndex >= 0) root.pasteClipEntry(root.clipFiltered[currentIndex]) }
                    Keys.onEscapePressed:  root.close()
                    Keys.onUpPressed:      { if (currentIndex <= 0) searchField.forceActiveFocus(); else decrementCurrentIndex() }

                    delegate: Item {
                        width: clipList.width
                        required property int index
                        property var  entry: root.clipFiltered[index]
                        property bool isHov: false
                        property bool isFoc: ListView.isCurrentItem

                        height: entry && entry.isImage
                            ? Math.min(clipList.width * 0.6, 200)
                            : Math.max(48, clipText.implicitHeight + 20)

                        Behavior on height { NumberAnimation { duration: 80 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            clip: true
                            color: isFoc ? ColorsModule.Colors.surface_container_high
                                 : isHov ? ColorsModule.Colors.surface_container
                                 :         "transparent"
                            border.color: isFoc ? ColorsModule.Colors.primary : "transparent"
                            border.width: isFoc ? 1.5 : 0
                            Behavior on color        { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                source: entry && entry.isImage && entry.thumbPath !== ""
                                    ? "file://" + entry.thumbPath + "?gen=" + root._thumbGen : ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true; mipmap: true; asynchronous: true; cache: false
                                visible: entry && entry.isImage
                            }
                            Text {
                                anchors.centerIn: parent; text: "🖼"
                                font.pixelSize: 26
                                visible: entry && entry.isImage && thumbImg.status !== Image.Ready
                            }

                            Text {
                                id: clipText
                                visible: entry && !entry.isImage
                                anchors {
                                    left: parent.left; right: parent.right
                                    leftMargin: 12; rightMargin: 12
                                    top: parent.top; topMargin: 10
                                }
                                text: entry ? entry.preview : ""
                                font { pixelSize: 13; family: "Noto Sans" }
                                color: isFoc
                                    ? ColorsModule.Colors.on_surface
                                    : ColorsModule.Colors.on_surface_variant
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                maximumLineCount: 10
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: { isHov = true; clipList.currentIndex = index }
                                onExited:  isHov = false
                                onClicked: root.pasteClipEntry(root.clipFiltered[index])
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.clipFiltered.length === 0
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰅍"; font.family: "Material Design Icons"; font.pixelSize: 32
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.3
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.clipAllEntries.length === 0 ? "No clipboard history" : "No matches"
                            font { pixelSize: 13; family: "Noto Sans" }
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.55
                        }
                    }
                }

                // ── Emoji ─────────────────────────────────────────────────────

                GridView {
                    id: emojiGrid
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: root.currentTab === 1
                    clip: true
                    cellWidth: 56; cellHeight: 56
                    currentIndex: -1
                    model: root.emojiFiltered

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 3; radius: 2
                            color: ColorsModule.Colors.outline; opacity: 0.6
                        }
                        background: Item {}
                    }

                    Keys.onReturnPressed: {
                        if (currentIndex >= 0) root.copyText(root.emojiFiltered[currentIndex].emoji)
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onUpPressed: {
                        const cols = Math.max(1, Math.floor(emojiGrid.width / emojiGrid.cellWidth))
                        if (currentIndex < cols) searchField.forceActiveFocus()
                        else moveCurrentIndexUp()
                    }

                    delegate: Item {
                        width: emojiGrid.cellWidth; height: emojiGrid.cellHeight
                        required property int index
                        property var  item:  root.emojiFiltered[index]
                        property bool isHov: false
                        property bool isFoc: GridView.isCurrentItem

                        Rectangle {
                            anchors { fill: parent; margins: 3 }
                            radius: 10
                            color: isFoc ? ColorsModule.Colors.surface_container_high
                                 : isHov ? ColorsModule.Colors.surface_container
                                 :         "transparent"
                            border.color: isFoc ? ColorsModule.Colors.primary : "transparent"
                            border.width: isFoc ? 1.5 : 0
                            Behavior on color        { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: item ? item.emoji : ""
                                font.pixelSize: 26
                                scale: isHov ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: { isHov = true; emojiGrid.currentIndex = index }
                            onExited:  isHov = false
                            onClicked: root.copyText(root.emojiFiltered[index].emoji)
                            ToolTip.visible: containsMouse
                            ToolTip.text:    item ? item.name + "\n" + item.category : ""
                            ToolTip.delay:   500
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.emojiFiltered.length === 0
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰞅"; font.family: "Material Design Icons"; font.pixelSize: 32
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.3
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No emoji found"
                            font { pixelSize: 13; family: "Noto Sans" }
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.55
                        }
                    }
                }

                // ── Kaomoji ───────────────────────────────────────────────────

                ListView {
                    id: kaoList
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.bottomMargin: 6
                    visible: root.currentTab === 2
                    clip: true
                    spacing: 3
                    currentIndex: -1
                    model: root.kaoFiltered

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 3; radius: 2
                            color: ColorsModule.Colors.outline; opacity: 0.6
                        }
                        background: Item {}
                    }

                    Keys.onReturnPressed:  { if (currentIndex >= 0) root.copyText(root.kaoFiltered[currentIndex].text) }
                    Keys.onEscapePressed:  root.close()
                    Keys.onUpPressed:      { if (currentIndex <= 0) searchField.forceActiveFocus(); else decrementCurrentIndex() }

                    delegate: Item {
                        width: kaoList.width; height: 46
                        required property int index
                        property var  item:  root.kaoFiltered[index]
                        property bool isHov: false
                        property bool isFoc: ListView.isCurrentItem

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: isFoc ? ColorsModule.Colors.surface_container_high
                                 : isHov ? ColorsModule.Colors.surface_container
                                 :         "transparent"
                            border.color: isFoc ? ColorsModule.Colors.primary : "transparent"
                            border.width: isFoc ? 1.5 : 0
                            Behavior on color        { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                spacing: 10

                                Text {
                                    Layout.fillWidth: true
                                    text: item ? item.text : ""
                                    font { pixelSize: 14; family: "Noto Sans" }
                                    color: isFoc
                                        ? ColorsModule.Colors.on_surface
                                        : ColorsModule.Colors.on_surface_variant
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Rectangle {
                                    visible: item && item.category !== ""
                                    height: 18; width: catLabel.implicitWidth + 12
                                    radius: 6
                                    color: ColorsModule.Colors.surface_container_high
                                    Text {
                                        id: catLabel
                                        anchors.centerIn: parent
                                        text: item ? item.category : ""
                                        font { pixelSize: 10; family: "Noto Sans" }
                                        color: ColorsModule.Colors.on_surface_variant
                                        elide: Text.ElideRight; maximumLineCount: 1
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: { isHov = true; kaoList.currentIndex = index }
                                onExited:  isHov = false
                                onClicked: root.copyText(root.kaoFiltered[index].text)
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: root.kaoFiltered.length === 0
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰙃"; font.family: "Material Design Icons"; font.pixelSize: 32
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.3
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No kaomoji found"
                            font { pixelSize: 13; family: "Noto Sans" }
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.55
                        }
                    }
                }
            }

            // ── Footer ────────────────────────────────────────────────────────

            Item {
                Layout.fillWidth: true
                height: 38

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 1
                    color: ColorsModule.Colors.outline_variant; opacity: 0.4
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 18
                    spacing: 6

                    Rectangle {
                        width: 5; height: 5; radius: 3
                        color: ColorsModule.Colors.primary; opacity: 0.6
                    }
                    Text {
                        text: root.currentTab === 0
                            ? root.clipFiltered.length + " item" + (root.clipFiltered.length !== 1 ? "s" : "")
                            : root.currentTab === 1
                            ? root.emojiFiltered.length + " emoji"
                            : root.kaoFiltered.length + " kaomoji"
                        font { pixelSize: 11; family: "Noto Sans" }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.currentTab === 0
                            ? "↵ paste  ·  Esc close"
                            : "↵ copy  ·  Esc close"
                        font { pixelSize: 11; family: "Noto Sans" }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.35
                    }
                }
            }
        }
    }
}
