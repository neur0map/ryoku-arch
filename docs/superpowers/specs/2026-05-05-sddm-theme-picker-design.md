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
- All elevation goes through `pkexec` (not bare sudo) so the picker
  works without a controlling tty. The polkit-gnome agent already
  running in the Ryoku session surfaces a graphical password dialog.
  See "Privileged helpers" below for the two scripts the picker
  invokes under pkexec (`ryoku-set-sddm-theme`, `ryoku-install-qylock`).
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

The page owns an inline `ListModel` of providers. Each entry has a
`kind` discriminator: `"builtin"` for providers that ship pre-installed
with Ryoku-shell (no install workflow, always present), or `"external"`
for providers that need a user-triggered install step.

```qml
ListModel {
  id: providers

  // Built-in: ships with Ryoku-shell via
  // shell/scripts/sddm/install-pixel-sddm.sh. Always installed,
  // no Install button.
  ListElement {
    providerId: "ii-pixel"
    kind: "builtin"
    displayName: "ii-pixel"
    author: "Ryoku project"
    repoUrl: ""                  // built-in; no repo
    description: "Built-in pixel-art SDDM theme that ships with " +
                 "Ryoku. Material You dynamic colors driven by " +
                 "your wallpaper palette."
    accentColor: ""              // empty = use theme primary
    licenseLabel: "MIT"
    themesDirOnDisk: "/usr/share/sddm/themes"
    bundledAssetDir: "shell/assets/sddm-providers/ii-pixel"
    heroAsset: "hero.png"
    themesAssetDir: "themes"
    placeholderAsset: "_placeholder.png"
    bundledThemes: ["ii-pixel"]  // single-theme provider
  }

  // External: cloned + copied on demand by ryoku-install-qylock.
  ListElement {
    providerId: "qylock"
    kind: "external"
    displayName: "qylock"
    author: "Darkkal44"
    repoUrl: "https://github.com/Darkkal44/qylock"
    description: "Optional bundle of animated, video-capable SDDM " +
                 "themes by Darkkal44. Cloned to " +
                 "~/.local/share/qylock and copied into the system " +
                 "SDDM themes dir on demand."
    accentColor: "#8f1d21"       // qylock's red, used only on
                                  // Install button + active-theme
                                  // border for this provider
    licenseLabel: "GPL-3.0"
    installRoot: "$HOME/.local/share/qylock"
    themesPath: "themes"         // relative to installRoot
    themesDirOnDisk: "/usr/share/sddm/themes"
    bundledAssetDir: "shell/assets/sddm-providers/qylock"
    heroAsset: "hero.png"
    themesAssetDir: "themes"
    placeholderAsset: "_placeholder.png"
    bundledThemes: []            // populated at implementation time
                                  // from upstream qylock; see
                                  // "Bundled preview assets" section
                                  // below for the manifest source
                                  // of truth
  }
}
```

The `ListModel` is plain QML data, not a config knob. Providers are
defined in source. To add a new provider, an implementer adds a
`ListElement` block and drops asset files under
`shell/assets/sddm-providers/<providerId>/`.

There is **no** `installCommand` field. The resolver maps
`providerId` directly to the privileged operation:

- `kind: "builtin"`: install workflow is N/A. Apply-theme workflow
  invokes `pkexec ryoku-set-sddm-theme <themeName>` (new helper, see
  "Privileged helpers" below).
- `qylock` install: `pkexec ryoku-install-qylock --default` (after the
  helper is refactored to drop privs for git ops; see "Privileged
  helpers").
- `qylock` apply theme:
  `pkexec ryoku-install-qylock --theme <themeName>`.
- future providers: add a branch keyed by `providerId`.

Both kinds of subprocess run via Quickshell's `Process` component
(matching the existing pattern in `GeneralConfig.qml`,
`NiriConfig.qml`, `ToolsConfig.qml`, `QuickConfig.qml`), not via
`Quickshell.execDetached`. `Process` exposes `running`, `exitCode`,
and stdout/stderr capture, which the page needs to know when an
install or apply has actually finished and whether to surface a
failure toast.

**Why `pkexec` and not `sudo`:** Quickshell `Process` runs without a
controlling tty, so plain `sudo` cannot prompt for a password and
either fails or hangs. `pkexec` routes the prompt through the running
`polkit-gnome-authentication-agent-1` (already part of the Ryoku
session), which surfaces a graphical dialog. This is the same pattern
the existing `shell/setup` script uses (see
`shell/setup:157,176,185,2334`).

### Privileged helpers

Two helpers live in `bin/` and are the only things the picker invokes
under `pkexec`. Both are designed to be safe-to-run-as-root:

1. **`bin/ryoku-set-sddm-theme <name>`** (new). Validates `name` is a
   directory under `/usr/share/sddm/themes/<name>` and writes
   `[Theme]\nCurrent=<name>` to `/etc/sddm.conf.d/theme.conf`,
   creating the dir if missing. This is the entire helper. Used for
   built-in providers (ii-pixel) and as the primitive any future
   non-clone provider could call. Idempotent.

2. **`bin/ryoku-install-qylock`** (existing, **needs refactor**).
   Today the helper assumes user-mode and shells out to `sudo` for the
   theme dir copy and `theme.conf` write. The picker needs it to be
   safe-to-run-via-pkexec, which requires:

   - At entry, detect `EUID == 0`. If true and `SUDO_USER` is set,
     run all `git clone`/`git pull` commands under
     `sudo -u "$SUDO_USER"` so `~/.local/share/qylock` ends up
     owned by the invoking user, not root.
   - The existing `sudo cp -r` and `sudo tee` lines become bare
     `cp -r` and `tee` when `EUID == 0` (already privileged), or
     keep the `sudo` prefix when run user-mode from a terminal
     (existing behavior preserved). A small wrapper function
     (`_priv()` returns empty when root, "sudo" otherwise) captures
     this.
   - The `ryoku-pkg-add` call: `ryoku-pkg-add` already handles its
     own elevation; running it as root should be a no-op for elevation
     and just delegates to pacman. Verify no double-elevation issues
     during implementation.

   The terminal-mode invocation (`ryoku-install-qylock` typed by a
   user at a shell) keeps working unchanged. Only adding a code path
   for root-mode entry.

The picker invokes these only via the `pkexec` argv prefix:
`["pkexec", "ryoku-set-sddm-theme", themeName]`,
`["pkexec", "ryoku-install-qylock", "--default"]`,
`["pkexec", "ryoku-install-qylock", "--theme", themeName]`.

### Active-theme detection

SDDM merges every `*.conf` file under `/etc/sddm.conf.d/` in
alphabetical order; later files override earlier ones for the same
key. Today on a working Ryoku install this directory typically
contains:

- `autologin.conf` (autologin user/session, not theme)
- `inir-theme.conf` (stale, leftover from before the iNiR-to-Ryoku
  rebrand; not written by current code, but may exist on
  upgraded systems)
- `ryoku-shell-theme.conf` (written by
  `shell/scripts/sddm/install-pixel-sddm.sh`; sets
  `Current=ii-pixel`)
- `theme.conf` (written by `ryoku-install-qylock` and the new
  `ryoku-set-sddm-theme`; alphabetically the last `theme/Current=`
  source, so the picker's selection always wins)

The page reads the active theme by listing
`/etc/sddm.conf.d/*.conf` in alphabetical order and using the **last**
`Current=` line found across the merged files (matching SDDM's own
behavior). It does **not** read `theme.conf` exclusively, because on
a system where the picker has never run the only `Current=` line lives
in `ryoku-shell-theme.conf`.

If no `Current=` line exists in any file, the banner shows
`"system default (breeze)"` (SDDM's compiled-in fallback).

The page does not attempt to clean up `inir-theme.conf` or any other
stale file. That is out of scope here; a future migration can do it.

### Page layout

Top to bottom:

1. **Active-theme banner.** SettingsCardSection-style container at the
   top of the page. Left side: `MaterialSymbol { text: "login" }` plus
   the literal active theme name in monospace (resolved per "Active-theme
   detection" above). Right side: a small caption,
   `"Greeter shown before login. Reboot or 'systemctl restart sddm'
   to apply changes."` Two-line caption, dim color.

2. **Provider cards.** One `Repeater` over the `providers` ListModel.
   Each provider renders as a single SettingsCardSection-styled card.
   Layout depends on `kind`:

   **`kind: "builtin"` (e.g. ii-pixel):**

   - Hero strip across the top, full card width, ~140px tall, bleeds
     to the card's rounded corners. Source: bundled
     `<bundledAssetDir>/<heroAsset>`.
   - Below the hero:
     - Provider name + author in dim color: `ii-pixel  ·  by Ryoku project`
     - Description paragraph
     - Status pill: `"Built-in"`, filled with theme primary at low alpha
     - **No Install button.** The theme is always installed.
     - Thumbnail grid below (single tile for ii-pixel, since
       `bundledThemes` has one entry). Tile follows the same active-theme
       highlight rules as below.

   **`kind: "external"` pre-install** (`installRoot` does not exist or
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
     - Below the text block, a small thumbnail strip: up to 4 of the
       `bundledThemes` rendered at 16:9 ~120x68 each, with a
       `"+N more"` chip if the provider has more than 4. These are
       the same per-theme bundled assets used post-install, just
       smaller. If `bundledThemes` is empty (e.g. because the asset
       manifest has not yet been captured), the strip falls back to a
       single placeholder tile showing
       `"Preview after install"` text. This is a deliberate signal
       that the implementer still owes upstream-derived previews.
     - Install button at the bottom right, filled with the provider's
       `accentColor`, label `"Install qylock"`. Clicking it triggers
       the install workflow (see "Install workflow" below).

   **`kind: "external"` post-install** (`installRoot/.git` exists):

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
       `accentColor` (or theme primary for `kind: "builtin"`),
       plus a small `"Active"` chip in the top-right corner.
       Inactive tiles have no border and no chip.
     - Click target on the entire tile: applies that theme. While
       the apply subprocess is running, the tile shows a spinner
       overlay and ignores clicks.
   - The Install button is replaced by a single `"Update qylock"`
     ghost button (lower visual weight) that runs the same
     `pkexec ryoku-install-qylock --theme <currently-active>` command;
     this re-pulls the qylock repo and re-copies the active theme
     so themes added upstream become available.

### Install workflow (external providers only)

Built-in providers have no install workflow. For `kind: "external"`:

Click "Install qylock" → page sets a single `Process` component's
`command` to `["pkexec", "ryoku-install-qylock", "--default"]` and
toggles `running = true`. `pkexec` triggers the polkit graphical
dialog; once the user authenticates the helper runs as root.

`--default` is correct because:

1. On a brand-new install with no qylock present, the helper installs
   Qt deps, clones qylock (as the original user via `sudo -u
   $SUDO_USER` per the refactor), and seats `dog-samurai`. This
   matches what the migration does, so the picker behaves the same as
   the migration on first run.
2. If qylock is already partially installed somehow, the helper's
   own logic (the `if [[ -d $QYLOCK_DIR/.git ]]` branch) keeps the
   already-active theme rather than blowing it away. So clicking
   Install on a partially-broken install is safe.

While `Process.running` is true the page shows a non-blocking
"Installing qylock…" banner at the top and disables the Install
button. The `Process.exited` signal (fires once with the exit code
when the helper finishes) drives the next state:

- `exitCode === 0`: re-evaluate provider state (the
  `installRoot/.git` check now returns true; the page flips into
  post-install layout, and the active-theme banner re-runs
  active-theme detection).
- `exitCode === 126` or `127`: polkit dialog was cancelled or
  helper not found. Show a quiet toast `"Install cancelled."` and
  leave state untouched.
- other non-zero: surface a failure toast,
  `"Install failed (exit <code>). Run 'ryoku-install-qylock' in a
  terminal to see output."` Banner is dismissed.

No timer-based polling. The exit signal is authoritative.

### Apply-theme workflow

Click a tile → a second `Process` component (separate from the
install one, so an in-flight install does not block apply or vice
versa) gets its `command` set based on the provider kind:

- `kind: "builtin"` (ii-pixel): `["pkexec", "ryoku-set-sddm-theme", themeName]`
- `kind: "external"` (qylock): `["pkexec", "ryoku-install-qylock", "--theme", themeName]`

For ii-pixel, the helper just writes `[Theme]\nCurrent=ii-pixel` to
`/etc/sddm.conf.d/theme.conf`. For qylock, the helper additionally
copies the theme directory into `/usr/share/sddm/themes/<name>` (a
no-op if it is already current and unchanged).

Tile shows a spinner overlay while the apply Process is running.
Polkit prompts via the polkit-gnome agent. On `Process.exited` with
exit code 0, the page re-runs active-theme detection and updates the
banner and tile highlight. On exit 126/127 (cancelled), no toast,
state untouched. On other non-zero, surface a failure toast and leave
the active theme unchanged.

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
      _placeholder.png         # shared fallback across providers
      ii-pixel/
        hero.png
        themes/
          ii-pixel.png
      qylock/
        hero.png
        themes/
          <theme-name>.png ... # one per upstream qylock theme;
                               # the manifest is captured at
                               # implementation time, not enumerated
                               # in this spec
```

All images are PNG, target output size 1280x720, file size budget
~250KB each. They are real screenshots, not synthetic mockups.

**ii-pixel assets:** captured from a running ii-pixel session on a
Ryoku install. Single theme, single thumbnail. The hero can be a
crop or recolor of the theme thumbnail.

**qylock assets:** the implementer enumerates qylock's `themes/`
directory at upstream HEAD, captures one screenshot per theme, and
populates `bundledThemes` in the QML `ListElement` with the same
list of names. The spec does not enumerate the names because they
change as upstream qylock evolves; the test (see "Tests" below)
asserts the QML list and the asset directory stay in sync. Source
images can be lifted from qylock's upstream README and its themes'
own preview images, with attribution in `CREDITS.md`.

`hero.png` for qylock is a stylized composition (layered crops of
multiple themes, slight desaturation, subtle vignette) rather than a
single theme's screenshot. This avoids implying a default theme
before the user has picked one.

`_placeholder.png` is a flat, low-contrast pattern with the literal
text "preview unavailable" centered in Ryoku's body font. Used only
when both live and bundled assets are missing for a theme. Shared
across all providers.

The implementation does not generate these assets. Capturing the
qylock screenshots, the ii-pixel screenshot, the hero composites,
and rendering the placeholder are the implementer's responsibility
before the feature ships.

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
   contains the inline `providers` `ListModel`.
2. Asserts the new page is registered in `shell/settings.qml`'s
   `pages` array (grep for `LoginScreenConfig.qml`).
3. Asserts a search entry for the new page exists in
   `shell/modules/settings/SettingsOverlay.qml` (grep for the keyword
   `"qylock"` inside `settingsSearchIndex`).
4. Per provider, parses the `bundledThemes` list out of
   `LoginScreenConfig.qml` (one provider block at a time) and asserts
   every entry has a matching asset under
   `shell/assets/sddm-providers/<providerId>/themes/<name>.png`. This
   prevents the ListModel and asset directory from drifting. For
   `kind: "external"` providers, the `bundledThemes` list may be empty
   (no upstream snapshot captured yet), in which case the test
   accepts the empty case but warns.
5. Asserts each provider has its `hero.png` under
   `shell/assets/sddm-providers/<providerId>/`, and the shared
   `shell/assets/sddm-providers/_placeholder.png` exists. All are real
   PNGs (`file -b` magic check contains `PNG image data`).
6. Asserts `bin/ryoku-set-sddm-theme` exists, is executable, and
   contains a `pkexec`-safe shape (no `sudo` calls, since pkexec already
   runs it as root).
7. Asserts `bin/ryoku-install-qylock` contains the EUID-detection
   refactor (grep for `EUID` and `SUDO_USER`), confirming it is
   safe-to-run-via-pkexec.
8. Lints both helper scripts via `shellcheck` if available (skip with
   a warning otherwise).

The test does not run quickshell, does not start SDDM, does not call
either privileged helper, and does not depend on `qmllint` or any
other QML tooling (the repo currently has none and this spec does not
introduce one). It is pure static validation. Behavioral verification
(does the install actually work, does the apply actually switch
themes, does pkexec actually surface a dialog) stays manual.

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
  any other community SDDM theme bundle. Each only requires a
  `ListElement` plus asset directory; no UI changes.
- **Uninstall flow.** Deferred until the failure modes are well
  understood. Listed in non-goals above.
- **`inir-theme.conf` cleanup migration.** The stale file from before
  the iNiR-to-Ryoku rebrand is harmless (it sets the same theme as
  `ryoku-shell-theme.conf`) but should eventually be removed. Out of
  scope here; can be a one-line migration in a future commit.

## Open Questions

None at this point. Common-sense review applied; spec aligns with the
real on-disk state of qylock, ii-pixel, and `/etc/sddm.conf.d/`.
