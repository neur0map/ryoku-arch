// Hash router: maps #/<panel> to the visible panel and the active nav item, and
// plays a clip-path wipe on swap (skipped under prefers-reduced-motion).

const PANELS = ["overview", "vault", "agents", "chat"];
const reduce = () =>
  typeof matchMedia !== "undefined" &&
  matchMedia("(prefers-reduced-motion: reduce)").matches;

function current() {
  const h = location.hash.replace(/^#\/?/, "");
  return PANELS.includes(h) ? h : "overview";
}

export function initRouter(onChange) {
  const panels = document.querySelectorAll("[data-panel]");
  const links = document.querySelectorAll("[data-nav]");

  function show(name) {
    panels.forEach((p) => {
      const active = p.dataset.panel === name;
      p.hidden = !active;
      if (active && !reduce()) {
        p.classList.remove("wipe-in");
        void p.offsetWidth; // restart the animation
        p.classList.add("wipe-in");
      }
    });
    links.forEach((l) => l.classList.toggle("active", l.dataset.nav === name));
    if (onChange) onChange(name);
  }

  addEventListener("hashchange", () => show(current()));
  show(current());
}
