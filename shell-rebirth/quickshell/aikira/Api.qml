pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string base: "http://127.0.0.1:7842/api/v1"

    // ── Generic helpers ────────────────────────────────────────────────────

    function get(path, cb) {
        const r = new XMLHttpRequest()
        r.open("GET", base + path)
        r.setRequestHeader("Content-Type", "application/json")
        r.onreadystatechange = function() {
            if (r.readyState !== 4) return
            if (r.status >= 200 && r.status < 300) {
                cb(null, JSON.parse(r.responseText))
            } else {
                cb(r.status + ": " + r.responseText, null)
            }
        }
        r.send()
    }

    function post(path, body, cb) {
        const r = new XMLHttpRequest()
        r.open("POST", base + path)
        r.setRequestHeader("Content-Type", "application/json")
        r.onreadystatechange = function() {
            if (r.readyState !== 4) return
            if (r.status >= 200 && r.status < 300) {
                cb(null, JSON.parse(r.responseText))
            } else {
                cb(r.status + ": " + r.responseText, null)
            }
        }
        r.send(JSON.stringify(body))
    }

    function patch(path, body, cb) {
        const r = new XMLHttpRequest()
        r.open("PATCH", base + path)
        r.setRequestHeader("Content-Type", "application/json")
        r.onreadystatechange = function() {
            if (r.readyState !== 4) return
            if (r.status >= 200 && r.status < 300) {
                cb(null, JSON.parse(r.responseText))
            } else {
                cb(r.status + ": " + r.responseText, null)
            }
        }
        r.send(JSON.stringify(body))
    }

    function del(path, cb) {
        const r = new XMLHttpRequest()
        r.open("DELETE", base + path)
        r.setRequestHeader("Content-Type", "application/json")
        r.onreadystatechange = function() {
            if (r.readyState !== 4) return
            if (r.status >= 200 && r.status < 300) {
                cb(null, JSON.parse(r.responseText))
            } else {
                cb(r.status + ": " + r.responseText, null)
            }
        }
        r.send()
    }

    // ── Domain helpers ─────────────────────────────────────────────────────

    function loadCharacters(cb)          { get("/characters/", cb) }
    function loadPersonas(cb)            { get("/personas/", cb) }
    function loadProxies(cb)             { get("/proxies/", cb) }
    function loadConversations(charId, cb) {
        get("/conversations/?character_id=" + charId, cb)
    }
    function loadMessages(convId, cb)    { get("/conversations/" + convId + "/messages", cb) }

    function createCharacter(data, cb)   { post("/characters/", data, cb) }
    function updateCharacter(id, data, cb) { patch("/characters/" + id, data, cb) }
    function deleteCharacter(id, cb)     { del("/characters/" + id, cb) }

    function createPersona(data, cb)     { post("/personas/", data, cb) }
    function updatePersona(id, data, cb) { patch("/personas/" + id, data, cb) }
    function deletePersona(id, cb)       { del("/personas/" + id, cb) }

    function createProxy(data, cb)       { post("/proxies/", data, cb) }
    function updateProxy(id, data, cb)   { patch("/proxies/" + id, data, cb) }
    function deleteProxy(id, cb)         { del("/proxies/" + id, cb) }
    function testProxy(id, cb)           { post("/proxies/" + id + "/test", {}, cb) }

    function createConversation(charId, personaId, firstMessage, cb) {
        const body = { character_id: charId, user_persona_id: personaId || null, title: "New Chat" }
        if (firstMessage) body.first_message = firstMessage
        post("/conversations/", body, cb)
    }

    function deleteConversation(id, cb)  { del("/conversations/" + id, cb) }
    function deleteMessage(convId, msgId, cb) { del("/conversations/" + convId + "/messages/" + msgId, cb) }
    function updateConversationTitle(id, title, cb) {
        patch("/conversations/" + id, { title: title }, cb)
    }
}
