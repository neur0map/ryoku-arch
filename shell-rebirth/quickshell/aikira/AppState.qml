pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // ── Data ───────────────────────────────────────────────────────────────
    property var characters:   []
    property var personas:     []
    property var proxies:      []
    property var conversations: []
    property var messages:     []

    // ── Selection ──────────────────────────────────────────────────────────
    property var activeCharacter:   null
    property var activeConversation: null
    property var activePersona:     null

    // ── UI state ───────────────────────────────────────────────────────────
    // "chat" | "character_editor" | "proxy_manager" | "persona_selector"
    property string view: "chat"
    property var    editingCharacter: null   // null = creating new
    property var    editingProxy:     null

    property bool   streaming:    false
    property string streamBuffer: ""         // accumulates current token stream

    // ── Response alternatives (in-memory reroll history) ───────────────────
    // Populated when a reroll happens; cleared when user sends a new message
    // or switches conversation.  Index 0 = original response.
    property var  lastAiAlternatives: []
    property int  lastAiAltIndex:     0

    // ── Signals ────────────────────────────────────────────────────────────
    signal errorOccurred(string msg)
    signal conversationCreated(var conv)

    // ── Bootstrap ──────────────────────────────────────────────────────────
    function bootstrap() {
        Api.loadCharacters(function(err, data) {
            if (err) { root.errorOccurred(err); return }
            root.characters = data
        })
        Api.loadPersonas(function(err, data) {
            if (err) return
            root.personas = data
            // pick default persona
            const def = data.find(p => p.is_default)
            if (def) root.activePersona = def
            else if (data.length > 0) root.activePersona = data[0]
        })
        Api.loadProxies(function(err, data) {
            if (err) return
            root.proxies = data
        })
    }

    // ── Character actions ──────────────────────────────────────────────────
    function selectCharacter(char) {
        root.activeCharacter = char
        root.activeConversation = null
        root.messages = []
        root.streamBuffer = ""
        root.view = "chat"
        Api.loadConversations(char.id, function(err, data) {
            if (err) return
            root.conversations = data
            if (data.length > 0) selectConversation(data[0])
        })
    }

    function selectConversation(conv) {
        root.activeConversation = conv
        root.messages = []
        root.streamBuffer = ""
        root.lastAiAlternatives = []
        root.lastAiAltIndex = 0
        Api.loadMessages(conv.id, function(err, data) {
            if (err) { root.errorOccurred(err); return }
            root.messages = data
        })
    }

    function switchAiAlternative(index) {
        if (index < 0 || index >= root.lastAiAlternatives.length) return
        root.lastAiAltIndex = index
        const msgs = root.messages ? root.messages.slice() : []
        for (let i = msgs.length - 1; i >= 0; i--) {
            if (msgs[i] && msgs[i].role === "assistant" && msgs[i].id !== "streaming") {
                msgs[i] = { id: msgs[i].id, role: "assistant",
                    content: root.lastAiAlternatives[index],
                    created_at: msgs[i].created_at }
                root.messages = msgs
                break
            }
        }
    }

    function newConversation() {
        if (!root.activeCharacter) return
        const personaId = root.activePersona ? root.activePersona.id : null
        const firstMsg = root.activeCharacter.first_message || null
        Api.createConversation(root.activeCharacter.id, personaId, firstMsg, function(err, conv) {
            if (err) { root.errorOccurred(err); return }
            root.conversations = [conv].concat(root.conversations)
            root.activeConversation = conv
            root.messages = []
            root.streamBuffer = ""
            root.lastAiAlternatives = []
            root.lastAiAltIndex = 0
            // Load messages so the persisted first_message (if any) appears immediately
            if (firstMsg) {
                Api.loadMessages(conv.id, function(lerr, data) {
                    if (!lerr) root.messages = data
                })
            }
            root.conversationCreated(conv)
        })
    }

    function refreshCharacters() {
        Api.loadCharacters(function(err, data) {
            if (err) return
            root.characters = data
        })
    }

    function refreshProxies() {
        Api.loadProxies(function(err, data) {
            if (err) return
            root.proxies = data
        })
    }

    function refreshPersonas() {
        Api.loadPersonas(function(err, data) {
            if (err) return
            root.personas = data
        })
    }
}
