// Vault panel: left file list (generated files get a GEN stamp), right rendered
// markdown. REINDEX posts /api/index and runs a scanline sweep on the pane while
// the request is in flight.

import { api } from "./api.js";
import { mdToHtml, escapeHtml } from "./markdown.js";

export function initVault(root) {
  const listEl = root.querySelector("[data-vault-list]");
  const pane = root.querySelector("[data-vault-pane]");
  const reindexBtn = root.querySelector("[data-vault-reindex]");
  let current = null;

  function renderList(files) {
    if (!files.length) {
      listEl.innerHTML = '<li class="dim">no files</li>';
      return;
    }
    listEl.innerHTML = files.map((f) => {
      const gen = f.generated ? '<span class="stamp stamp-gen">GEN</span>' : "";
      return (
        '<li><button class="vault-item" data-p="' + escapeHtml(f.path) + '">' +
        '<span class="vault-name">' + escapeHtml(f.path) + "</span>" + gen +
        "</button></li>"
      );
    }).join("");
  }

  async function load() {
    try {
      const data = await api.vault();
      renderList(data.files || []);
      const first = (data.files || [])[0];
      if (first && !current) open(first.path);
    } catch (err) {
      listEl.innerHTML = '<li class="dim">vault unavailable</li>';
      pane.innerHTML = '<p class="dim">Start the daemon to browse the vault.</p>';
    }
  }

  async function open(rel) {
    current = rel;
    listEl.querySelectorAll(".vault-item").forEach((b) =>
      b.classList.toggle("active", b.dataset.p === rel));
    try {
      const md = await api.vaultFile(rel);
      pane.innerHTML = mdToHtml(md);
    } catch (err) {
      pane.innerHTML = '<p class="dim">could not read ' + escapeHtml(rel) + "</p>";
    }
  }

  listEl.addEventListener("click", (e) => {
    const btn = e.target.closest(".vault-item");
    if (btn) open(btn.dataset.p);
  });

  if (reindexBtn) {
    reindexBtn.addEventListener("click", async () => {
      pane.classList.add("scanline");
      reindexBtn.disabled = true;
      try {
        await api.reindex();
        current = null;
        await load();
      } catch (err) {
        pane.innerHTML = '<p class="dim">reindex failed</p>';
      } finally {
        pane.classList.remove("scanline");
        reindexBtn.disabled = false;
      }
    });
  }

  load();
}
