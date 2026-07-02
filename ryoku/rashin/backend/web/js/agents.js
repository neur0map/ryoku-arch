// Agents panel: one row per agent (name, file path, wired state), with WIRE /
// UNWIRE stamp buttons hitting the agents API. Absent agents show a dim state
// and disabled buttons.

import { api } from "./api.js";
import { escapeHtml } from "./markdown.js";

export function initAgents(root) {
  const listEl = root.querySelector("[data-agents-list]");

  function row(a) {
    const stateChip = a.wired
      ? '<span class="stamp stamp-ok">WIRED</span>'
      : a.present
        ? '<span class="stamp stamp-idle">UNWIRED</span>'
        : '<span class="stamp stamp-bad">ABSENT</span>';
    const action = a.wired
      ? '<button class="btn btn-ghost" data-act="unwire" data-id="' + escapeHtml(a.id) + '">UNWIRE</button>'
      : '<button class="btn btn-primary" data-act="wire" data-id="' + escapeHtml(a.id) + '"' +
        (a.present ? "" : " disabled") + ">WIRE</button>";
    return (
      '<div class="agent-row" data-id="' + escapeHtml(a.id) + '">' +
      '<div class="agent-id"><span class="agent-name">' + escapeHtml(a.name) + "</span>" +
      '<span class="agent-file">' + escapeHtml(a.file || "") + "</span></div>" +
      '<div class="agent-state">' + stateChip + action + "</div></div>"
    );
  }

  async function load() {
    try {
      const list = await api.agents();
      listEl.innerHTML = (list || []).map(row).join("");
    } catch (err) {
      listEl.innerHTML = '<p class="dim">agents unavailable, start the daemon</p>';
    }
  }

  listEl.addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-act]");
    if (!btn || btn.disabled) return;
    btn.disabled = true;
    try {
      await (btn.dataset.act === "wire" ? api.wire(btn.dataset.id) : api.unwire(btn.dataset.id));
    } catch (err) { /* reload reflects real state */ }
    await load();
  });

  load();
}
