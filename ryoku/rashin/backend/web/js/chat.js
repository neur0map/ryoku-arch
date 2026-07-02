// Chat panel: a pure reducer (applyEvent) that the node tests drive directly,
// plus a DOM layer that only wakes when a document exists. The reducer owns all
// protocol state so rendering stays a dumb projection of it.

import { mdToHtml } from "./markdown.js";
import { wsUrl } from "./api.js";

export function initialState() {
  return {
    items: [], // ordered stream: {kind:'msg'|'tool', ...}
    permissions: [], // pending permission requests
    banner: { state: "starting", model: "", error: "" },
    busy: false,
    seq: 0,
  };
}

function lastOpenAgentMsg(items) {
  for (let i = items.length - 1; i >= 0; i--) {
    const it = items[i];
    if (it.kind === "msg" && it.role === "agent" && it.open) return it;
  }
  return null;
}

// applyEvent(state, ev) -> next state. Never mutates the input; always returns a
// fresh object so the DOM layer can diff cheaply. ev is a daemon->client frame
// (chat WS protocol) or the local {type:'permission_reply'} echo.
export function applyEvent(state, ev) {
  const s = {
    items: state.items,
    permissions: state.permissions,
    banner: state.banner,
    busy: state.busy,
    seq: state.seq,
  };
  switch (ev.type) {
    case "user": {
      s.items = state.items.concat({
        kind: "msg", role: "user", text: ev.text || "", open: false, id: "u" + ++s.seq,
      });
      return s;
    }
    case "agent_text": {
      let msg = lastOpenAgentMsg(state.items);
      if (!msg) {
        msg = { kind: "msg", role: "agent", text: "", thought: "", open: true, id: "a" + ++s.seq };
        s.items = state.items.concat(msg);
      } else {
        s.items = state.items.slice();
      }
      const idx = s.items.indexOf(msg);
      s.items[idx] = Object.assign({}, msg, { text: msg.text + (ev.text || "") });
      return s;
    }
    case "agent_thought": {
      let msg = lastOpenAgentMsg(state.items);
      if (!msg) {
        msg = { kind: "msg", role: "agent", text: "", thought: "", open: true, id: "a" + ++s.seq };
        s.items = state.items.concat(msg);
      } else {
        s.items = state.items.slice();
      }
      const idx = s.items.indexOf(msg);
      s.items[idx] = Object.assign({}, msg, { thought: (msg.thought || "") + (ev.text || "") });
      return s;
    }
    case "tool": {
      const at = state.items.findIndex((it) => it.kind === "tool" && it.id === ev.id);
      if (at === -1) {
        s.items = state.items.concat({
          kind: "tool", id: ev.id, title: ev.title || "", kind2: ev.kind || "",
          status: ev.status || "pending",
        });
      } else {
        s.items = state.items.slice();
        const prev = s.items[at];
        s.items[at] = Object.assign({}, prev, {
          title: ev.title != null ? ev.title : prev.title,
          kind2: ev.kind != null ? ev.kind : prev.kind2,
          status: ev.status != null ? ev.status : prev.status,
        });
      }
      return s;
    }
    case "permission": {
      s.permissions = state.permissions.concat({
        requestId: ev.requestId, title: ev.title || "", options: ev.options || [],
      });
      return s;
    }
    case "permission_reply": {
      s.permissions = state.permissions.filter((p) => p.requestId !== ev.requestId);
      return s;
    }
    case "turn_end": {
      const msg = lastOpenAgentMsg(state.items);
      if (msg) {
        s.items = state.items.slice();
        s.items[s.items.indexOf(msg)] = Object.assign({}, msg, { open: false });
      }
      s.busy = false;
      return s;
    }
    case "state": {
      s.banner = { state: ev.state || "", model: ev.model || "", error: ev.error || "" };
      s.busy = ev.state === "busy" || ev.state === "starting";
      return s;
    }
    default:
      return state;
  }
}

// ---- DOM layer (browser only) ----------------------------------------------

if (typeof document !== "undefined") {
  const STATE_LABEL = {
    starting: "STARTING", ready: "READY", busy: "BUSY", dead: "OFFLINE",
  };
  const STATUS_STAMP = {
    pending: "PENDING", in_progress: "IN PROGRESS", completed: "DONE", failed: "FAILED",
  };

  window.initChat = function initChat(root) {
    const stream = root.querySelector("[data-chat-stream]");
    const banner = root.querySelector("[data-chat-banner]");
    const perms = root.querySelector("[data-chat-perms]");
    const form = root.querySelector("[data-chat-form]");
    const input = root.querySelector("[data-chat-input]");
    const sendBtn = root.querySelector("[data-chat-send]");
    const cancelBtn = root.querySelector("[data-chat-cancel]");

    let state = initialState();
    let ws = null;
    let backoff = 500;
    let closed = false;

    function dispatch(ev) {
      state = applyEvent(state, ev);
      render();
    }

    function send(obj) {
      if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj));
    }

    const emptyHTML =
      '<div class="chat-empty">' +
      '<img src="assets/chat-empty.webp" alt="" onerror="this.parentElement.hidden = true">' +
      "<p>The compass is listening. Ask about your machine.</p></div>";

    function renderStream() {
      if (!state.items.length) {
        stream.innerHTML = emptyHTML;
        return;
      }
      stream.innerHTML = state.items.map((it) => {
        if (it.kind === "tool") {
          return (
            '<div class="tool-card" data-status="' + it.status + '">' +
            '<div class="tool-head"><span class="tool-title">' + esc(it.title) + "</span>" +
            '<span class="tool-kind">' + esc(it.kind2) + "</span></div>" +
            '<span class="stamp stamp-status">' + (STATUS_STAMP[it.status] || it.status) + "</span>" +
            "</div>"
          );
        }
        if (it.role === "user") {
          return (
            '<div class="msg msg-user"><div class="msg-head">YOU</div>' +
            '<div class="msg-body">' + esc(it.text) + "</div></div>"
          );
        }
        const thought = it.thought
          ? '<details class="thinking"><summary>THINKING</summary><div class="thought-body">' +
            esc(it.thought) + "</div></details>"
          : "";
        const caret = it.open ? '<span class="caret">\u25AE</span>' : "";
        return (
          '<div class="msg msg-agent"><div class="msg-head">\u7F85\u91DD</div>' +
          thought +
          '<div class="msg-body">' + mdToHtml(it.text) + caret + "</div></div>"
        );
      }).join("");
      stream.scrollTop = stream.scrollHeight;
    }

    function renderPerms() {
      perms.innerHTML = state.permissions.map((p) => {
        const btns = p.options.map((o) => {
          const allow = /^allow/.test(o.kind || "") || /^allow/i.test(o.id || "");
          return (
            '<button class="hanko ' + (allow ? "hanko-allow" : "hanko-deny") +
            '" data-req="' + esc(p.requestId) + '" data-opt="' + esc(o.id) + '">' +
            esc(o.name || o.id) + "</button>"
          );
        }).join("");
        return (
          '<div class="perm-card"><div class="perm-title">' + esc(p.title) + "</div>" +
          '<div class="hanko-row">' + btns + "</div></div>"
        );
      }).join("");
    }

    function renderBanner() {
      const b = state.banner;
      banner.dataset.state = b.state;
      let txt = STATE_LABEL[b.state] || b.state;
      if (b.model) txt += " / " + b.model;
      if (b.state === "dead") {
        txt += b.error ? " / " + b.error : " / hermes unavailable, run setup";
      } else if (b.error) {
        txt += " / " + b.error;
      }
      banner.textContent = txt;
      const live = b.state !== "dead";
      input.disabled = !live;
      sendBtn.disabled = !live;
      cancelBtn.hidden = !state.busy;
    }

    function render() {
      renderStream();
      renderPerms();
      renderBanner();
    }

    perms.addEventListener("click", (e) => {
      const btn = e.target.closest(".hanko");
      if (!btn) return;
      const requestId = btn.dataset.req;
      send({ type: "permission", requestId, optionId: btn.dataset.opt });
      dispatch({ type: "permission_reply", requestId });
    });

    form.addEventListener("submit", (e) => {
      e.preventDefault();
      submit();
    });
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        submit();
      }
    });
    function submit() {
      const text = input.value.trim();
      if (!text || input.disabled) return;
      send({ type: "user", text });
      dispatch({ type: "user", text });
      state.busy = true;
      renderBanner();
      input.value = "";
      input.style.height = "auto";
    }
    input.addEventListener("input", () => {
      input.style.height = "auto";
      input.style.height = Math.min(input.scrollHeight, 160) + "px";
    });
    cancelBtn.addEventListener("click", () => send({ type: "cancel" }));

    function connect() {
      try {
        ws = new WebSocket(wsUrl("/ws/chat"));
      } catch (err) {
        scheduleReconnect();
        return;
      }
      ws.onopen = () => { backoff = 500; };
      ws.onmessage = (m) => {
        let ev;
        try { ev = JSON.parse(m.data); } catch (err) { return; }
        dispatch(ev);
      };
      ws.onclose = () => {
        if (!closed) {
          dispatch({ type: "state", state: "dead", error: "connection lost" });
          scheduleReconnect();
        }
      };
      ws.onerror = () => { try { ws.close(); } catch (err) { /* noop */ } };
    }
    function scheduleReconnect() {
      setTimeout(connect, backoff);
      backoff = Math.min(backoff * 2, 8000);
    }

    render();
    connect();
    return { destroy() { closed = true; if (ws) try { ws.close(); } catch (err) { /* noop */ } } };
  };

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }
}
