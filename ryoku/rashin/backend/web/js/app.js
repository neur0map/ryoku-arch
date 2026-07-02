// Dashboard entry point. Boots the router and each panel controller, and paints
// the overview daemon/hermes status stamps from /api/status. Everything degrades
// to dim placeholders when the daemon is absent.

import { initRouter } from "./router.js";
import { initVitals } from "./vitals.js";
import { initVault } from "./vault.js";
import { initAgents } from "./agents.js";
import { api } from "./api.js";
import "./chat.js";

function stamp(el, ok, okText, badText) {
  if (!el) return;
  el.textContent = ok ? okText : badText;
  el.className = "stamp " + (ok ? "stamp-ok" : "stamp-bad");
}

async function paintStatus() {
  try {
    const s = await api.status();
    stamp(document.querySelector("[data-s=daemon]"), s.running, "OK", "DOWN");
    const h = s.hermes || {};
    stamp(document.querySelector("[data-s=hermes]"), h.installed && h.wired, "OK", "MISSING");
  } catch (err) {
    stamp(document.querySelector("[data-s=daemon]"), false, "OK", "DOWN");
    stamp(document.querySelector("[data-s=hermes]"), false, "OK", "MISSING");
  }
}

function boot() {
  const started = {};
  initRouter((name) => {
    if (started[name]) return;
    started[name] = true;
    if (name === "vault") initVault(document.querySelector('[data-panel="vault"]'));
    else if (name === "agents") initAgents(document.querySelector('[data-panel="agents"]'));
    else if (name === "chat") {
      const el = document.querySelector('[data-panel="chat"]');
      if (typeof window.initChat === "function") window.initChat(el);
    }
  });
  initVitals(document.querySelector('[data-panel="overview"]'));
  paintStatus();
  setInterval(paintStatus, 5000);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot);
} else {
  boot();
}
