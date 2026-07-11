# The store

Ryoku's extras are delivered through a **store**: a browsable catalogue of
bundles and plugins that install into the running desktop with no setup, and
remove just as cleanly. The catalogue is a separate repo (`ryoku-extras`); the
store UI lives in the Hub; the shell hosts whatever a bundle brings.

## How it works today

- **Catalogue = `ryoku-extras`.** Each kind of thing (bundles, plugins,
  nautilus packs, livewalls, colorschemes) is a folder with a `registry.json`.
  An item is invisible to the shell until it is listed there. The Hub fetches
  the repo at runtime (`RYOKU_EXTRAS_BASE`, default the GitHub `main` raw tree)
  and caches it under `~/.cache/ryoku/extras`, so the catalogue still renders
  offline.
- **Store UI = the Hub.** Ryoku Settings has an **Add-ons -> Store** section
  with **Plugins** and **Bundles** tabs: image-rich cards (hero, install badge,
  source and count chips), a detail view, and one install action. Managing
  what is already installed lives on the Add-ons page.
- **Install = the actuator.** `ryoku-extras-install` routes each bundle item by
  type: `package` through `pacman -Syu` / the AUR helper (one package at a time,
  so one failure never strands the rest), `script` through `installers/<name>.sh`,
  and `plugin` / `nautilus-pack` through the shell's guest paths. It runs in a
  floating terminal for the sudo prompt; a bundle's `requires` (such as
  `multilib`) is ensured first. Removal is symmetric.
- **Guests = host/guest.** The shell is the *host*; a bundle ships *guests*
  (a plugin that renders in a widget or frame-popout host, a nautilus pack that
  drops right-click scripts). A guest declares its host and mounts on install,
  reload, and use with no extra setup; removing the bundle takes the guest and
  its state with it. All the guest's code lives in `ryoku-extras`, not here, so
  the shell stays a host and the catalogue stays independent.

## Should the store be a standalone app?

A recurring idea is to build a standalone **Ryoku Store**, the way `ryowalls`
(wallpapers) and `ryovm` (VMs) are their own Quickshell apps, instead of a Hub
section. This is the honest analysis, because the answer shapes where effort
goes next.

### The case for

- **Consistency + discoverability.** A named "Ryoku Store" in the app menu and
  on a keybind signals *this is where you get things*, the way an app store
  defines a platform. It is launchable from anywhere without opening Settings.
- **Room to browse.** A dedicated window can afford categories, search,
  screenshot galleries, and featured content that feel cramped in a settings
  tab.
- **Identity.** As the curated ecosystem becomes a differentiator, a flagship
  store is a thing users talk about and a front door for new arrivals.

### The case against (and what it does not buy you)

- **It duplicates a surface that already exists and works.** The Hub store was
  just reworked to be image-rich. A second implementation is either a fork to
  keep in sync with the catalogue schema, the backend, and the theme, or a
  shared-component extraction you could do without a second app.
- **It changes nothing about installing.** Install still needs the actuator, a
  sudo terminal, and (for guests) a shell retune. A standalone window is a
  nicer front end, not a functional gain.
- **Two doors to one room.** With both a Hub tab and a standalone app, users
  have to learn which one to use. Fragmentation, not clarity.
- **`ryowalls` / `ryovm` are not the same shape.** Those are distinct *tools*
  with their own domain and live state (a wallpaper browser, a VM manager). A
  store is a *management* surface, which is exactly what the Hub is for.

### The future-facing read

The distro's real differentiator is the **modular guest model** (bundles that
bring their own code and mount with no setup) and a catalogue rich enough to
matter. The store is the delivery vehicle for that, and its *packaging* (a Hub
tab versus a standalone window) is a smaller lever than the model and the
catalogue themselves. Spending a build cycle on a second store shell now, while
the catalogue is still small, optimizes the vehicle before the cargo is worth a
dedicated truck.

### Recommendation

**Do not build the standalone app yet.** Keep the store in the Hub, make it
excellent, and grow the catalogue and its integrity checks (the guest model, the
`tests/validate-catalogue.sh` gate in `ryoku-extras`). That is where the
attractiveness and the moat come from.

**Revisit it when** any of these is true: the catalogue spans several categories
(bundles, plugins, themes, wallpapers, colorschemes) and a single Hub tab feels
cramped; you want the store as a marketed front door for onboarding (a first-run
"get started" surface); or a non-Settings context needs store access.

**Build toward it now, cheaply,** by keeping the store's cards, detail view, and
backend calls **host-agnostic** so they can be lifted into a `Ryoku.Store`
Quickshell module that *both* the Hub tab and a future `qs -c ryostore` app
import. Then a standalone store is a packaging decision, not a rewrite, and there
is one store implementation with two hosts, mirroring the host/guest split the
rest of the system already uses.
