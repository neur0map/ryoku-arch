// Overview vitals: live system stats via /ws/vitals, falling back to 2s polling
// of /api/vitals when the socket fails. Numeric stat blocks tick from old to new
// value over 300ms (rAF), gated by prefers-reduced-motion.

import { api, wsUrl } from "./api.js";

export function formatBytes(n) {
  const gib = Number(n) / (1024 * 1024 * 1024);
  return gib.toFixed(1) + " GiB";
}

export function formatUptime(sec) {
  sec = Math.max(0, Math.floor(Number(sec) || 0));
  const d = Math.floor(sec / 86400);
  const h = Math.floor((sec % 86400) / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const parts = [];
  if (d) parts.push(d + "d");
  if (h || d) parts.push(h + "h");
  parts.push(m + "m");
  return parts.join(" ");
}

const reduce = () =>
  typeof matchMedia !== "undefined" &&
  matchMedia("(prefers-reduced-motion: reduce)").matches;

// tick(el, from, to, fmt): animate the number el.textContent through
// intermediate integers over 300ms. fmt formats each frame's value.
function tick(el, from, to, fmt) {
  if (reduce() || from === to || !Number.isFinite(from)) {
    el.textContent = fmt(to);
    return;
  }
  const start = performance.now();
  const dur = 300;
  function frame(now) {
    const p = Math.min(1, (now - start) / dur);
    const v = from + (to - from) * p;
    el.textContent = fmt(v);
    if (p < 1) requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

export function initVitals(root) {
  const last = {};
  function num(sel, value, fmt) {
    const el = root.querySelector(sel);
    if (!el) return;
    const to = Number(value);
    tick(el, last[sel] == null ? to : last[sel], to, fmt);
    last[sel] = to;
  }
  function txt(sel, value) {
    const el = root.querySelector(sel);
    if (el) el.textContent = value;
  }

  function apply(v) {
    if (!v) return;
    root.classList.remove("vitals-absent");
    txt("[data-v=host]", v.host || "unknown");
    txt("[data-v=kernel]", v.kernel || "unknown");
    txt("[data-v=uptime]", formatUptime(v.uptime));
    if (v.cpu) {
      num("[data-v=cpu-pct]", v.cpu.percent, (n) => Math.round(n) + "%");
      txt("[data-v=cpu-model]", (v.cpu.model || "") + (v.cpu.cores ? " / " + v.cpu.cores + "c" : ""));
    }
    if (v.mem) {
      const pct = v.mem.total ? (v.mem.used / v.mem.total) * 100 : 0;
      num("[data-v=mem-pct]", pct, (n) => Math.round(n) + "%");
      txt("[data-v=mem-detail]", formatBytes(v.mem.used) + " / " + formatBytes(v.mem.total));
    }
    if (Array.isArray(v.disks) && v.disks[0]) {
      const d = v.disks[0];
      const pct = d.total ? (d.used / d.total) * 100 : 0;
      num("[data-v=disk-pct]", pct, (n) => Math.round(n) + "%");
      txt("[data-v=disk-detail]", (d.mount || "/") + " " + formatBytes(d.used) + " / " + formatBytes(d.total));
    }
    const gpuBlock = root.querySelector("[data-block=gpu]");
    if (v.gpu) {
      if (gpuBlock) gpuBlock.classList.remove("stat-empty");
      num("[data-v=gpu-pct]", v.gpu.percent, (n) => Math.round(n) + "%");
      txt("[data-v=gpu-name]", v.gpu.name || "GPU");
    } else if (gpuBlock) {
      gpuBlock.classList.add("stat-empty");
      txt("[data-v=gpu-pct]", "--");
      txt("[data-v=gpu-name]", "no GPU");
    }
  }

  function markAbsent() {
    root.classList.add("vitals-absent");
  }

  let ws = null;
  let poll = null;
  let stopped = false;

  function startPolling() {
    if (poll) return;
    const run = () => api.vitals().then(apply).catch(markAbsent);
    run();
    poll = setInterval(run, 2000);
  }
  function stopPolling() {
    if (poll) { clearInterval(poll); poll = null; }
  }

  function connect() {
    try {
      ws = new WebSocket(wsUrl("/ws/vitals"));
    } catch (err) {
      startPolling();
      return;
    }
    ws.onmessage = (m) => {
      stopPolling();
      try { apply(JSON.parse(m.data)); } catch (err) { /* ignore bad frame */ }
    };
    ws.onerror = () => { if (!stopped) startPolling(); };
    ws.onclose = () => { if (!stopped) startPolling(); };
  }

  connect();
  return { destroy() { stopped = true; stopPolling(); if (ws) try { ws.close(); } catch (err) { /* noop */ } } };
}
