# SDDM Theme Picker (Login Screen Settings)

## Context

Today the SDDM (login screen) theme is managed entirely outside the
Settings UI. `bin/ryoku-install-qylock` (vendored helper) clones
`https://github.com/Darkkal44/qylock.git` to `~/.local/share/qylock`,
copies a chosen theme directory into `/usr/share/sddm/themes/<name>`,
and writes `[Theme]\nCurrent=<name>` to `/etc/sddm.conf.d/theme.conf`.
A migration (`migrations/1777002317.sh`) calls
`ryoku-install-qylock --default` once on fresh installs to seat
`dog-samurai` as the initial SDDM theme.

The Settings UI has a "Lock screen" section at `GeneralConfig.qml:783`
but it covers only the **session lock** (hyprlock-driven, in-shell), not
the SDDM greeter. There is currently no in-Settings way for a user to
discover that qylock exists, see what its themes look like, install it,
or switch the active SDDM theme without dropping to the terminal.

The user wants a dedicated Settings page that:

1. Lists SDDM theme providers (qylock first; the design must accommodate
   additional providers later without re-architecting).
2. Shows previews of each provider's themes **before installation** so
   the user is not committing blind, then expands the same card to a
   thumbnail grid post-install so they can switch between themes.
3. Treats provider install as opt-in. The page is visible regardless of
   install state; the Install button is the only thing that runs the
   helper.
4. Looks deliberately designed, not like an AI-generated card grid.
5. Stays within Ryoku's MIT license. qylock is GPL-3, but is invoked as
   a separate process (`ryoku-install-qylock` shells out to git, sudo,
   and the qylock theme tree) and not statically linked, so the
   aggregation boundary holds.

## Goals

- One new Settings page, "Login screen", surfacing SDDM theme management
  via existing Settings UI primitives (SettingsCardSection, RippleButton,
  StyledText, etc.) so it is visually consistent with the rest of
  Settings.
- Provider model is a list, not a singleton. qylock is the only entry at
  D0 ship, but adding "ii-pixel-themes", "sddm-sugar-candy", or any
  future provider must require only a new `ListElement` block plus an
  asset directory. No conditional branches on provider name in the UI
  layer.
- Pre-install state shows real screenshots bundled in the repo, not
  blank placeholders or "preview will appear after install" copy.
- Post-install state shows live per-theme thumbnails read from the
  installed qylock tree when those exist, falling back to the bundled
  asset, falling back to a generic placeholder.
- Active theme is highlighted unambiguously (border + chip), and the
  page header tells the user that switching themes only takes effect on
  reboot or `systemctl restart sddm`.
- All sudo escalation goes through the existing
  `ryoku-install-qylock` helper, which already calls `sudo` internally.
  Polkit prompts via the running `polkit-gnome-authentication-agent-1`.
- Page registers itself in `shell/settings.qml` and in the
  `SettingsOverlay.qml` search index so users can reach it via
  Ctrl+F search ("sddm", "login", "greeter", "qylock").

## Non-Goals

- Do **not** vendor qylock source into this repo. qylock stays a
  cloned dependency under `~/.local/share/qylock`. License boundary
  matters; we want a process boundary, not a derivative work.
- Do **not** build a generic SDDM `theme.conf` editor. The page
  manipulates the active theme name; nothing else under `[Theme]`,
  `[General]`, `[X11]`, etc. is touched.
- Do **not** expose qylock's per-theme custom settings (background
  color, blur amount, font, etc.) in this iteration. That is
  out-of-scope (D0 picker only). Future iterations may add a
  per-theme settings drawer, see "Future Work".
- Do **not** modify the existing session-lock "Lock screen" section in
  `GeneralConfig.qml`. The two pages stay distinct: session lock vs.
  greeter. The new page's section header copy makes the distinction
  explicit.
- Do **not** touch `migrations/1777002317.sh`. The default-seat behavior
  on fresh installs stays as is; the picker is for changing it later.
- Do **not** ship an "Uninstall qylock" button. Removing a theme
  bundle is not a workflow most users will perform, and doing it
  partially-correctly (leaving `/usr/share/sddm/themes/<name>`
  orphaned, leaving `theme.conf` pointing at a missing dir) breaks
  login. If the user wants to remove qylock they can `rm -rf
  ~/.local/share/qylock` themselves; this is a conscious omission.

## Architecture

### Page registration

A new `LoginScreenConfig.qml` lives at
`shell/modules/settings/LoginScreenConfig.qml`. It is registered in
`shell/settings.qml`'s `pages` array, inserted **after** the existing
"Compositor" entry (Niri) and **before** "About". It uses the Material
Symbol `login` and is marked `essential: false` so easy mode hides it
(consistent with Niri/Compositor).

`SettingsOverlay.qml`'s `settingsSearchIndex` gets one new entry so
search reaches the new page:

```qml
{
  pageIndex: <new index>,
  pageName: overlayPages[<new index>].name,
  section: Translation.tr("Login screen"),
  label: Translation.tr("SDDM theme"),
  description: Translation.tr("Greeter theme shown before login"),
  keywords: ["sddm", "login", "greeter", "theme", "qylock", "lockscreen"]
}
```

Inserting the page mid-array shifts every subsequent `pageIndex` in
`SettingsOverlay.qml`'s search index by one. The implementation must
update those indices, not just append. (The "About" page is currently
last; inserting before it shifts only the "About" entry.)

### Provider data model

The page owns an inline `ListModel` of providers. Each entry
captures everything the UI layer needs to render:

```qml
ListModel {
  id: providers
  ListElement {
    providerId: "qylock"
    displayName: "qylock"
    author: "Darkkal44"
    repoUrl: "https://github.com/Darkkal44/qylock"
    description: "Animated, video-capable SDDM themes by Darkkal44. " +
                 "Includes dog-samurai, neon-galaxy, fitgirl-repacks " +
                 "and several others."
    accentColor: "#8f1d21"           // qylock's red, used for
                                      // Install button + active-theme
                                      // border (per-provider accent)
    licenseLabel: "GPL-3.0"
    installRoot: "$HOME/.local/share/qylock"
    installCommand: "ryoku-install-qylock"   // arg shape:
                                              // [<cmd>, "--theme",
                                              // <theme name>]
    themesPath: "themes"             // relative to installRoot
    bundledAssetDir: "shell/assets/sddm-providers/qylock"
    heroAsset: "hero.png"            // relative to bundledAssetDir
    themesAssetDir: "themes"         // relative to bundledAssetDir
    placeholderAsset: "_placeholder.png"
    bundledThemes: [                 // pre-install preview manifest;
                                      // each entry needs a matching
                                      // <name>.png in themesAssetDir
      "dog-samurai", "neon-galaxy", "monochromatic-blur",
      "fitgirl-repacks", "japanese-aesthetic", "dark-blur",
      "anime-girl-stars"
    ]
  }
}
```

The `ListModel` is plain QML data, not a config knob. Providers are
defined in source. To add a new provider, an implementer adds a
`ListElement` block and drops asset files under
`shell/assets/sddm-providers/<providerId>/`.

`installCommand` is a string identifier, not a literal command line.
The page's helper logic resolves it to a real argv:

- `qylock` install: `["ryoku-install-qylock", "--default"]`
- `qylock` apply theme: `["ryoku-install-qylock", "--theme", <themeName>]`
- future providers: add a branch in the resolver keyed by `providerId`

Both kinds of subprocess are run via Quickshell's `Process` component
(matching the existing pattern in `GeneralConfig.qml`,
`NiriConfig.qml`, `ToolsConfig.qml`, `QuickConfig.qml`), not via
`Quickshell.execDetached`. `Process` exposes `running`, `exitCode`,
and stdout/stderr capture, which the page needs to know when an
install or apply has actually finished and whether to surface a
failure toast. This is the one place provider-specific logic lives.
The rest of the UI is data-driven.

### Page layout

Top to bottom:

1. **Active-theme banner.** SettingsCardSection-style container at the
   top of the page. Left side: `MaterialSymbol { text: "login" }` plus
   the literal active theme name in monospace (read from
   `/etc/sddm.conf.d/theme.conf`). Right side: a small caption,
   `"Greeter shown before login. Reboot or 'systemctl restart sddm'
   to apply changes."` Two-line caption, dim color.

   If no `theme.conf` exists or `Current=` is missing, banner shows
   `"system default (breeze)"` in monospace and the same caption.

2. **Provider cards.** One `Repeater` over the `providers` ListModel.
   Each provider renders as a single SettingsCardSection-styled card
   that has two visual states:

   **Pre-install state** (provider's `installRoot` does not exist or
   has no `.git`):

   - Hero strip across the top, full card width, ~140px tall, bleeds
     to the card's rounded corners. Source: bundled
     `<bundledAssetDir>/<heroAsset>`, scaled to fill, cropped centered.
   - Below the hero, in a horizontally-padded content block:
     - Provider name in title-size StyledText, with author appended
       in dim color: `qylock  ·  by Darkkal44`
     - Repo URL as a clickable, underlined link
     - Description paragraph (2-3 lines)
     - Status pill on the right: `"Not installed"`, subtle outline +
       neutral foreground (NOT the provider accent)
     - Below the text block, a small thumbnail strip: 4 of the
       `bundledThemes` rendered at 16:9 ~120x68 each, with a
       `"+N more"` chip if the provider has more than 4. These are
       the same per-theme bundled assets used post-install, just
       smaller.
     - Install button at the bottom right, filled with the provider's
       `accentColor`, label `"Install qylock"`. Clicking it triggers
       the install workflow (see "Install workflow" below).

   **Post-install state** (`installRoot/.git` exists):

   - Same hero strip (still useful as visual identity for the
     provider).
   - Same name/author/repo/description block, but the status pill
     becomes `"Installed"` with a filled background tint of the
     provider accent at low alpha.
   - Below the text block, a thumbnail **grid** rather than a strip.
     Tiles are 16:9 at ~200x112, in a wrap layout that reflows to the
     card width. One tile per theme found by listing
     `<installRoot>/<themesPath>/`. Each tile shows:
     - The theme's preview image. Resolution order:
       1. `<installRoot>/<themesPath>/<theme>/preview.png` if it
          exists (qylock ships these for some themes)
       2. `<bundledAssetDir>/<themesAssetDir>/<theme>.png` if the
          theme is in the provider's `bundledThemes` list
       3. `<bundledAssetDir>/<placeholderAsset>` as final fallback
     - Theme name overlay, bottom-left, on a dim-to-transparent
       gradient strip so it stays legible on any image
     - Active-theme highlight: 2px border in the provider's
       `accentColor`, plus a small `"Active"` chip in the top-right
       corner. Inactive tiles have no border (just the card's
       background) and no chip.
     - Click target on the entire tile: applies that theme. While
       the apply subprocess is running, the tile shows a spinner
       overlay and ignores clicks.
   - The Install button is replaced by a single `"Update qylock"`
     ghost button (lower visual weight) that runs the same
     `ryoku-install-qylock --theme <currently-active>` command;
     this re-pulls the qylock repo and re-copies the active theme
     so themes added upstream become available. (Re-pulling is
     already what `ryoku-install-qylock` does on every run.)

### Install workflow

Click "Install qylock" → page sets a single `Process` component's
`command` to `["ryoku-install-qylock", "--default"]` and toggles
`running = true`.

`--default` is correct because:

1. On a brand-new install with no qylock present, the helper installs
   Qt deps, clones qylock, and seats `dog-samurai`. This matches what
   the migration does, so the picker behaves the same as the migration
   on first run.
2. If qylock is already partially installed somehow, the helper's
   own logic (the `if [[ -d $QYLOCK_DIR/.git ]]` branch) keeps the
   already-active theme rather than blowing it away. So clicking
   Install on a partially-broken install is safe.

Polkit prompt comes from the `sudo` calls inside the helper. The
running `polkit-gnome-authentication-agent-1` (already part of the
Ryoku session) handles the prompt as a graphical dialog; no terminal
needed.

While `Process.running` is true the page shows a non-blocking
"Installing qylock…" banner at the top and disables the Install
button. The `Process.exited` signal (fires once with the exit code
when the helper finishes) drives the next state:

- `exitCode === 0`: re-evaluate provider state (the
  `installRoot/.git` check now returns true; the page flips into
  post-install layout, and the active-theme banner re-reads
  `theme.conf`).
- non-zero: surface a failure toast,
  `"Install failed (exit <code>). Run 'ryoku-install-qylock' in a
  terminal to see output."` Banner is dismissed.

No timer-based polling. The exit signal is authoritative.

### Apply-theme workflow

Click a tile in the post-install grid → a second `Process` component
(separate from the install one, so an in-flight install does not
block apply or vice versa) gets `command` set to
`["ryoku-install-qylock", "--theme", themeName]` and starts.

The helper writes `theme.conf` and copies the theme dir into
`/usr/share/sddm/themes/<name>`. Polkit prompts again. Tile shows a
spinner overlay while the apply Process is running. On
`Process.exited` with exit code 0, the page re-reads
`/etc/sddm.conf.d/theme.conf` (`Current=` line) and updates the
active-theme banner and tile highlight. On non-zero exit, surface a
failure toast and leave the active theme unchanged.

After a successful apply, page shows a transient toast at the bottom
of the page: `"Theme applied. Reboot or run 'systemctl restart sddm'."`
(matching the banner caption copy).

### Visual identity (avoiding AI-template look)

These are the deliberate design choices that distance the page from
generic Material/AI card grids:

- **Hero strip per provider.** Most settings cards in Ryoku are flat
  rectangles. Putting a real screenshot bleeding to the rounded corners
  immediately signals "this card is about a specific thing" rather
  than a generic settings row.
- **Per-provider accent color.** qylock's brand red (`#8f1d21`) is
  used **only** on the Install button and the active-theme border.
  Status pills, headings, descriptions, and the hero overlay use
  Ryoku's normal palette. The accent is a punctuation mark, not a
  theme.
- **Status pill, not "Status: Installed" label.** A small, rounded
  inline element. "Not installed" uses outline-only styling; "Installed"
  uses filled-low-alpha. The two states feel different at a glance.
- **Monospace for the active theme name.** Distinguishes a literal
  on-disk identifier from prose.
- **No emoji, no Material-symbol-only placeholders for themes.** Every
  pre-install thumbnail is a real screenshot. The `_placeholder.png`
  fallback is reserved for genuinely missing assets and is itself a
  designed image (subtle pattern + `"preview unavailable"` typography),
  not a question-mark glyph.
- **Caption tone.** "Greeter shown before login. Reboot or
  'systemctl restart sddm' to apply." is technical and specific. No
  "Customize your login screen experience!" marketing copy.
- **Card spacing matches the rest of Settings** (20px padding, 16px
  spacing) so the page feels native, not bolted on.

### Bundled preview assets

Repository layout:

```
shell/
  assets/
    sddm-providers/
      qylock/
        hero.png
        _placeholder.png
        themes/
          dog-samurai.png
          neon-galaxy.png
          monochromatic-blur.png
          fitgirl-repacks.png
          japanese-aesthetic.png
          dark-blur.png
          anime-girl-stars.png
```

All images are PNG, target output size 1280x720 (downscaled from
qylock's source themes), file size budget ~250KB each (so the seven
qylock thumbnails plus hero and placeholder weigh ~2.5MB total in the
repo). They are real screenshots captured from running qylock themes,
not synthetic mockups.

`hero.png` is a stylized composition representing qylock as a brand
(layered crops of multiple themes, slight desaturation, subtle vignette)
rather than a single theme's screenshot. This avoids implying a
default theme to the user before they have picked one.

`_placeholder.png` is a flat, low-contrast pattern with the literal
text "preview unavailable" centered in Ryoku's body font. Used only
when both live and bundled assets are missing for a theme.

The implementation does not generate these assets. Capturing the seven
qylock screenshots, cropping the hero composite, and rendering the
placeholder are the implementer's responsibility before the feature
ships. Source images can be lifted from qylock's upstream README and
its themes' own preview images, with attribution in `CREDITS.md`.

### Attribution

`CREDITS.md` already credits qylock and Darkkal44 for the theme bundle.
This spec adds one more line:

> Preview screenshots in `shell/assets/sddm-providers/qylock/themes/`
> are derived from qylock's upstream theme directories
> (https://github.com/Darkkal44/qylock) and are redistributed under
> qylock's GPL-3.0 license. Hero composite is an original Ryoku
> composition using qylock screenshots as source material.

The repo's MIT license applies to the **code** under `shell/`. The
bundled images are dual-attributed: GPL-3 for the originals, the
composite hero is also GPL-3 by virtue of being derived from GPL-3
material. This does not contaminate Ryoku's MIT code license because
the assets are aggregated, not linked: they are loaded at runtime by
the QML layer and are otherwise unrelated to the rest of the codebase.

The qylock helper itself (`bin/ryoku-install-qylock`) is original code
that calls `git`, `sudo`, and the user's Bash; it is not a derivative
of qylock and stays MIT.

### Tests

A new bash test under `tests/login-screen-config.sh`, following the
same pattern as existing static-validation tests in the repo (pure
shell assertions, no QML runtime):

1. Asserts `shell/modules/settings/LoginScreenConfig.qml` exists and
   contains the inline `providers` `ListModel` (grep for the
   identifier).
2. Asserts the new page is registered in `shell/settings.qml`'s
   `pages` array (grep for `LoginScreenConfig.qml`).
3. Asserts a search entry for the new page exists in
   `shell/modules/settings/SettingsOverlay.qml` (grep for the keyword
   `"qylock"` inside `settingsSearchIndex`).
4. Asserts every `providerId: "qylock"` `bundledThemes` entry parsed
   out of `LoginScreenConfig.qml` has a matching asset under
   `shell/assets/sddm-providers/qylock/themes/<name>.png`. This
   prevents the ListModel and asset directory from drifting.
5. Asserts `shell/assets/sddm-providers/qylock/hero.png` and
   `_placeholder.png` exist and are real PNGs (`file -b` magic check
   contains `PNG image data`).

The test does not run quickshell, does not start SDDM, does not call
`ryoku-install-qylock`, and does not depend on `qmllint` or any other
QML tooling (the repo currently has none and this spec does not
introduce one). It is pure static validation. Behavioral verification
(does the install actually work, does the apply actually switch
themes) stays manual.

## Future Work

Out of scope for D0; documented so the design accommodates them.

- **D1: per-theme generic settings.** Some qylock themes ship a
  `theme.conf.user` (or similar) with k/v overrides. A future
  iteration could read that file when a theme is active and expose a
  generic `key=value` editor under the active tile. Provider data
  model would gain a `customSettingsPath` field; the rest of the UI
  is unchanged.
- **D2: curated per-theme controls.** Beyond a generic editor, a
  provider could ship a small QML schema describing its custom
  settings (sliders, toggles, color pickers). qylock would be the
  first to define one. The `ListElement` would gain a
  `customSettingsSchema` field pointing at a QML file under the
  provider's bundled assets. Out of scope here.
- **Additional providers.** `sddm-sugar-candy`, `sddm-astronaut`, and
  Ryoku's own `ii-pixel` (currently the SDDM theme on this machine)
  could be added as providers. Each only requires a `ListElement` plus
  asset directory; no UI changes.
- **Uninstall flow.** Deferred until the failure modes are well
  understood. Listed in non-goals above.

## Open Questions

None at this point. Design approved by the user; spec ready for review
before plan handoff.
