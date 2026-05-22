import QtQuick
import qs.aikira
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../colors" as ColorsModule
import qs.aikira.components

Item {
    id: root
    implicitWidth:  1100
    implicitHeight: 720

    Component.onCompleted: {
        AppState.bootstrap()
        // Reload active conversation messages each time the panel is opened.
        // This covers the case where the Loader destroys and recreates the component
        // (aikiraLoader.active = false → true) while AppState's singleton persists.
        if (AppState.activeConversation && !AppState.streaming) {
            Api.loadMessages(AppState.activeConversation.id, function(err, data) {
                if (!err) AppState.messages = data
            })
        }
    }

    Connections {
        target: AppState
        function onErrorOccurred(msg) { errorToast.show(msg) }
    }

    // ── SSE streaming process ──────────────────────────────────────────────
    Process {
        id: streamProc
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                if (!line || !line.trim()) return
                let evt
                try { evt = JSON.parse(line) } catch(e) { return }

                if (evt.type === "token") {
                    // Only update streamBuffer — the streaming bubble binds to it directly,
                    // so no messages array replacement is needed and the ListView stays stable.
                    AppState.streamBuffer = AppState.streamBuffer + evt.content

                } else if (evt.type === "done") {
                    const msgs = AppState.messages ? AppState.messages.slice() : []
                    for (let i = msgs.length - 1; i >= 0; i--) {
                        if (msgs[i] && msgs[i].id === "streaming") {
                            msgs[i] = { id: evt.message_id, role: "assistant",
                                content: AppState.streamBuffer,
                                created_at: new Date().toISOString() }
                            break
                        }
                    }
                    AppState.messages = msgs
                    // Append completed response to alternatives list when rerolling
                    if (AppState.lastAiAlternatives.length > 0) {
                        const alts = AppState.lastAiAlternatives.concat([AppState.streamBuffer])
                        AppState.lastAiAlternatives = alts
                        AppState.lastAiAltIndex = alts.length - 1
                    }
                    AppState.streamBuffer = ""
                    AppState.streaming    = false
                    streamProc.running    = false

                } else if (evt.type === "error") {
                    AppState.errorOccurred(evt.detail)
                    AppState.streaming    = false
                    AppState.streamBuffer = ""
                    streamProc.running    = false
                }
            }
        }
    }

    function sendMessage(text) {
        if (!AppState.activeConversation || AppState.streaming) return
        if (!text || !text.trim()) return

        // Sending a new message locks in the current response — clear alternatives
        AppState.lastAiAlternatives = []
        AppState.lastAiAltIndex = 0

        const msgs = AppState.messages ? AppState.messages.slice() : []
        msgs.push({ id: "user_" + Date.now(), role: "user",
            content: text, created_at: new Date().toISOString() })
        msgs.push({ id: "streaming", role: "assistant",
            content: "", created_at: new Date().toISOString() })
        AppState.messages     = msgs
        AppState.streamBuffer = ""
        AppState.streaming    = true

        streamProc.command = [
            "python3",
            Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/scripts/aikira/aikira-stream.py",
            AppState.activeConversation.id,
            text
        ]
        streamProc.running = true
    }

    function rerollMessage() {
        if (!AppState.activeConversation || AppState.streaming) return

        // On the very first reroll, capture the original response as alternatives[0]
        if (AppState.lastAiAlternatives.length === 0) {
            const cur = AppState.messages || []
            for (let i = cur.length - 1; i >= 0; i--) {
                if (cur[i] && cur[i].role === "assistant" && cur[i].id !== "streaming") {
                    AppState.lastAiAlternatives = [cur[i].content]
                    AppState.lastAiAltIndex = 0
                    break
                }
            }
        }

        const msgs = AppState.messages ? AppState.messages.slice() : []
        for (let i = msgs.length - 1; i >= 0; i--) {
            if (msgs[i] && msgs[i].role === "assistant" && msgs[i].id !== "streaming") {
                msgs.splice(i, 1)
                break
            }
        }
        msgs.push({ id: "streaming", role: "assistant",
            content: "", created_at: new Date().toISOString() })
        AppState.messages     = msgs
        AppState.streamBuffer = ""
        AppState.streaming    = true

        streamProc.command = [
            "python3",
            Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/scripts/aikira/aikira-stream.py",
            AppState.activeConversation.id,
            "--reroll"
        ]
        streamProc.running = true
    }

    Rectangle {
        anchors.fill: parent
        color: ColorsModule.Colors.background
        radius: 12
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
        }

        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: ColorsModule.Colors.outline_variant
            opacity: 0.5
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ChatPanel {
                anchors.fill: parent
                visible: AppState.view === "chat"
                onSendMessage: function(text) { root.sendMessage(text) }
                onRerollMessage: root.rerollMessage()
            }

            CharacterEditor {
                anchors.fill: parent
                visible: AppState.view === "character_editor"
            }

            ProxyManager {
                anchors.fill: parent
                visible: AppState.view === "proxy_manager"
            }

            PersonaSelector {
                anchors.fill: parent
                visible: AppState.view === "persona_selector"
            }

            CharacterBrowser {
                anchors.fill: parent
                visible: AppState.view === "character_browser"
            }
        }
    }

    ErrorToast {
        id: errorToast
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 24
        }
    }
}
