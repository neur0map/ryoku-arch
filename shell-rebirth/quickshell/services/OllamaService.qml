pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io


Singleton {
    id: root

    property string baseUrl: "http://127.0.0.1:11434"
    property bool   loading: false
    property bool   streaming: false
    property var    models: []


    signal modelsLoaded(var models)
    signal tokenReceived(string token)
    signal responseFinished(string full)
    signal errorOccurred(string message)

    property string _accumulatedResponse: ""
    property var    _pendingMessages: []
    property string _activeModel: ""


    function fetchModels() {
        _runShell(listProc, `curl -sf "${root.baseUrl}/api/tags"`)
    }

    Process {
        id: listProc
        onExited: (code, signal) => {
            if (code !== 0) {
                root.errorOccurred("Failed to fetch models (exit " + code + ")")
                return
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return
                try {
                    const json = JSON.parse(data)
                    const parsed = (json.models || []).map(m => ({
                        name:     m.name,
                        size:     _humanSize(m.size || 0),
                        modified: m.modified_at || ""
                    }))
                    root.models = parsed
                    root.modelsLoaded(parsed)
                } catch(e) {
                    root.errorOccurred("Model parse error: " + e)
                }
            }
        }
    }

    // ── Chat / Streaming ──────────────────────────────────────────────────────

    /**
     * Send a message to Ollama with streaming.
     *
     * @param {string} model   — model name, e.g. "llama3.2"
     * @param {Array}  history — [{role:"user"|"assistant", content:"..."}]
     * @param {string} message — the new user message
     */
    function sendMessage(model, history, message) {
        if (root.streaming) return

        root.streaming = true
        root._accumulatedResponse = ""
        root._activeModel = model

        const messages = history.concat([{ role: "user", content: message }])
        const body = JSON.stringify({
            model:    model,
            messages: messages,
            stream:   true
        })

        // Escape for shell single-quote context
        const escaped = body.replace(/'/g, `'"'"'`)
        const cmd = `curl -sf -X POST "${root.baseUrl}/api/chat" \
            -H 'Content-Type: application/json' \
            -d '${escaped}'`

        _runShell(chatProc, cmd)
    }

    /** Cancel an in-progress streaming response. */
    function cancelStreaming() {
        if (chatProc.running) chatProc.running = false
        root.streaming = false
    }

    Process {
        id: chatProc
        onExited: (code, signal) => {
            root.streaming = false
            if (code !== 0 && root._accumulatedResponse === "") {
                root.errorOccurred("Chat request failed (exit " + code + ")")
            } else {
                root.responseFinished(root._accumulatedResponse)
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            // Ollama streams one JSON object per line
            onRead: data => {
                if (!data || data.trim() === "") return
                try {
                    const obj = JSON.parse(data)
                    const token = obj?.message?.content ?? ""
                    if (token) {
                        root._accumulatedResponse += token
                        root.tokenReceived(token)
                    }
                } catch(e) {
                    // Partial line — ignore
                }
            }
        }
    }


    function _runShell(proc, cmd) {
        if (proc.running) {
            proc.running = false
        }
        proc.command = ["bash", "-c", cmd]
        proc.running = true
    }

    function _humanSize(bytes) {
        if (bytes === 0) return "?"
        const gb = bytes / 1_073_741_824
        if (gb >= 1) return gb.toFixed(1) + " GB"
        const mb = bytes / 1_048_576
        return mb.toFixed(0) + " MB"
    }
}
