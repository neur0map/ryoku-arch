# Changelog: ryoku/

## Unreleased

### Added
- `hyprland` + `system/hardware/power`: **clamshell mode -- close the lid without
  sleeping when docked.** A new `modules/lid.lua` binds the laptop lid switch
  (`bindl switch:Lid Switch`) to `ryoku-clamshell lid`, which blanks the internal
  panel on close when an external display is attached and restores the layout on
  open; autostart launches the `ryoku-clamshell` daemon that keeps the machine
  awake on lid close while on AC power with an external display (macOS-style: both
  are required, else it suspends). The suspend policy and the logind drop-in live
  in `system/hardware/power/`.
- `hyprland` + `shell/quickshell/ryolayer` + `system/hardware/audio`:
  **RyoLayer (`Super+G`): a transparent tool overlay over the desktop.** A
  board fades in over the compositor-blurred desktop, blur on a live slider
  (forced to the layer's own strength while open and restored on close, the
  launcher's serialized force/restore), hosting modular instrument widgets you
  drag, bracket-resize, and pin onto a `WlrLayer.Top` window that outlives the
  board. Ships two: a music controller (MPRIS transport, seek, art, player
  switch, and a real 10-band PipeWire equalizer with presets over a live cava
  ghost) and a microphone controller (gain, mute, device switch, live level,
  who's recording, one-tap unity normalize). The equalizer is a
  `module-filter-chain` sink (`ryoku-eq`, applied at login) and mic normalize
  is `ryoku-mic`, both with no extra packages. Layout persists to
  `ryolayer.json` as per-screen normalized centres, EQ state to `eq.json`.
  Toggled by `ryoku-shell ryolayer`; the Hub's keybind reference lists the
  bind since it reads `binds.lua` (`hyprland/modules/binds.lua`,
  `shell/quickshell/ryolayer/`, `system/hardware/audio/ryoku-eq`,
  `system/hardware/audio/ryoku-mic`; see `docs/ryolayer.md`).
- `hyprland` + `shell`: **`Super+Alt+D` opens the right (System) sidebar**, the
  mirror of `Super+D` for the left (Features) sidebar. The bind runs
  `ryoku-shell system`, a new IPC verb that toggles the System control centre;
  the Hub's keybind reference lists it automatically since it reads `binds.lua`
  (`hyprland/modules/binds.lua`, `shell/ipc/daemon.go`).
- `hyprland` + `hub`: **recordings are constant-framerate and crisp by default,
  and now configurable.** `ryoku-cmd-screenrecord` recorded variable-framerate
  with no quality flag, so clips felt like 30fps and imported as ~30 in editors.
  It now defaults to constant 60fps (`-fm cfr`) at `very_high`, and reads
  fps/quality/codec/encoder from `recording.json`, which the Hub's new Recording
  page writes. wf-recorder (the multi-GPU fallback) gained matching quality
  (VAAPI qp / x264 crf). Env vars still override everything.
- `hyprland` + `cli` + `shell`: **`user.lua` ships seeded with a header, not
  empty.** The hand-written override file Hyprland loads last is now seeded on
  install (like `keyboard.lua`) with a comment block spelling out the load
  order: Ryoku's base modules (replaced by updates), then `settings.lua`
  (generated from your Hub choices in `hypr.json`, rebuilt on Save), then
  `user.lua` (yours, never touched). `ryoku materialize` and `deploy.sh` seed
  it only when absent and never clobber it, so a hand-edit sticks across
  updates (`hyprland/user.lua`, `materialize.go`, `deploy.sh`).
- `rashin/backend`: **user.md works on a dev checkout now.** Without a packaged
  `/usr/share/ryoku/config`, Rashin gave up and treated all of `~/.config` as
  potentially user-owned. It now derives the baseline from the checkout
  `ryoku deploy` records (`~/.local/state/ryoku/repo`), diffing that checkout's
  `hyprland` tree, where the Ryoku-vs-user ownership actually lives, against
  `~/.config/hypr`; and even with no baseline at all it still names the
  always-user override files (`user.lua`, `monitors_user.lua`, ...), so an agent
  on a dev box can still tell Ryoku defaults from the user's own edits (`user.go`).
- `hyprland`: **Super+Esc opens the power menu** (`ryoku-shell power`) -- a
  vertical session strip (lock, logout, shutdown, restart, sleep). It is the
  delos bar's power access, since power leaves the island, but the bind works
  in every bar style.
- `rashin/backend` + `apps/fish` + `docs/rashin-terminal.md`: **Rashin in the
  terminal**, a third surface on the one brain (launcher `\`, dashboard, and
  now the command line). A new `rashin` command (the `ryoku-rashin` binary
  under a second name; argv0 routes a bare argument to a terminal ask) turns
  natural language into an answer plus a ready-to-run command plan and drops it
  on the fish prompt: `rashin take me to the fastfetch config`, `rashin scan
  Documents for pngs and move them into Pictures`. It answers on the daemon's
  fast lane (`POST /api/term`), the same direct chat-completions loop as the
  launcher, with a terminal persona, the terminal context (cwd, last command
  and its exit status), the read-only tools, and one action tool, `propose`,
  whose commands the daemon validates (binary on PATH, source paths exist) and
  tiers (read/write/system/danger via a deny-first Go classifier in
  `danger.go`). It never runs anything itself; the buffer is the confirmation
  and the tiers gate `--run`. Heavy asks escalate to the pre-warmed hermes
  session, and session-lane permission prompts are answered right in the
  terminal (`POST /api/perm`, answered exactly once even if the dashboard
  races). A `conf.d/rashin.fish` weave adds the interactive wrapper, an
  **Alt+R** binding that transmutes the current command line, a `fish_postexec`
  hook that reports proposed-vs-ran corrections, and the recipes loader. New
  **habits layer** (`habits.md`) mines this user's XDG directory names, modern
  tool substitutions (eza/zoxide/fd/rg/bat), and fish-history rhythms
  (secret-filtered, opt-out) into both ask lanes, so a command knows the folder
  is really `Pictures`. Repeated asks become saved **recipes** (`rr-<name>` fish
  abbreviations). Every surface reads and writes one ask history, so `\resume`,
  `rashin --resume`, and "continue in dashboard" see one conversation. New
  verbs: `term`, `term --report`; the `rashin` command also passes through
  `status`/`enable`/`disable`/`setup`/`index`.
- `shell/quickshell/overview` + `hyprland`: a new full-screen workspace overview
  (Super+Tab), a launcher-style expo that replaces the pill's workspace switcher.
  The compositor blurs the desktop (an `overview` layer rule) and a filmstrip
  shows the current desktop's workspaces as scaled mini-desktops with LIVE window
  previews (Quickshell `ScreencopyView` captures off-workspace toplevels, no
  compositor plugin). Click a workspace to switch, click a window to focus, drag
  a window between workspaces or up onto the desktop strip, hover a window for a
  ✕ that closes it, scroll/Tab to cycle the selection, Enter to commit, Esc to
  dismiss. Subtle Ryoku chrome: sharp corners, hard offset shadows, one
  vermillion accent, mono zero-padded workspace numerals with a small app-icon
  roster. A second level sits on top: DESKTOPS, each a block of ten workspace
  ids with its own 01..10 set; the top strip switches desktops (or Super+Alt+Tab
  cycles them) so you can keep separate sets of workspaces for different work.
  Empty gaps render as thin numbered slats so they stay visible and reachable
  without eating a full cell. `hyprland/scripts/ryoku-workspace` derives the
  current desktop from the active workspace and makes `Super+N` / `Super+Alt+N`
  desktop-relative (on desktop 2, `Super+3` focuses ws13, never ws3, and windows
  never jump desktops); the redundant Alt+Tab window switcher bind is removed.
- `rashin/backend` + `shell/quickshell/launcher`: the quick ask got real
  powers. The fast lane is now a bounded agent loop, not a one-shot: on a
  direct-provider connection it can call a small set of read-only Go-native
  tools (`system_query` for packages/updates/service/processes/disk/kernel/
  gpu/network, `read_file`, `list_dir`, `search_code` via prowl-agent, and
  `fetch_url`), up to four rounds, then answer, all still in a second or two.
  Tools are deliberately a safe Go set, not hermes's Python toolset; anything
  heavier (file or image generation, a real browser, a skill, system changes)
  replies `TOOLS_REQUIRED` and escalates to the pre-warmed session lane. Tool
  runs surface as cards in the dashboard and as the working label in the
  launcher. Every turn now runs on a background context, so **CONTINUE IN
  DASHBOARD** can open the live turn mid-flight and it keeps going after the
  launcher closes (proven: a SIGKILL'd CLI still completed the turn into
  hermes state.db and the ask history); **CANCEL** / Escape stops it via
  `/api/ask/cancel`. `\resume` lists recent asks from a persisted JSONL
  (`$XDG_STATE_HOME/ryoku/rashin-asks.jsonl`) and recalls a cached answer with
  its chips, no model call. New verbs: `ask --recent`, `ask --cancel`.
- `rashin/` + `hub/quickshell/RashinPage.qml` + `hyprland/modules/autostart`:
  **Ryoku Rashin**, an optional agent OS (off by default). `rashin/backend`
  (`ryoku-rashin`, one Go program) maintains a machine-generated markdown vault
  at `~/.local/share/ryoku/rashin/` (system, desktop, and package maps, fenced
  between `<!-- rashin:generated -->` markers so a reindex never clobbers user or
  agent notes), serves a hand-authored dashboard embedded under
  `rashin/backend/web/` on `127.0.0.1:3600` (localhost only), and bridges the
  Hermes agent over ACP into a web chat. A one-click `setup` installs and
  onboards Hermes, then wires reversible, marker-fenced vault pointers
  (`<!-- ryoku-rashin -->`) into every detected agent's global instructions
  (Claude Code, codex, opencode, omp, Hermes); an existing Hermes is never
  clobbered, and `serve` re-checks the wiring on start with any drift reported by
  `status`. The Hub gains a Rashin page in the Advanced group (enable toggle,
  one-click Hermes setup watched live, open-dashboard button), and `autostart`
  launches `ryoku-rashin serve --if-enabled`, which exits at once until enabled.
  See `docs/rashin.md`.
- `rashin/backend`: the dashboard grows from a glance into a **full local-agent
  utility** (v0.2.0), seven panels. Chat v2: image attach/paste/drag-drop (sent
  as ACP image blocks, downscaled client-side), clickable links, a `/` command
  legend fed live from Hermes's slash commands, a model picker with recents
  (switches over `session/set_model`), a session-history drawer that replays
  stored transcripts (`session/list` + `session/load`), a context-usage meter,
  token fade-in streaming, and a response-ready toast for backgrounded tabs.
  New **Memory** panel: provider detection (builtin or honcho/mem0/supermemory/
  hindsight and friends, plus Obsidian vault detection), a force-directed graph
  of the vault's notes and references, a 26-week activity heatmap, and Hermes
  session history read from `~/.hermes/state.db` (sqlite3, read-only). New
  **Skills** panel: all Hermes skills by category with origin counts (bundled /
  hub / agent-grown), live search, and the enabled toolbelt grouped into
  families. New **About** panel: what Rashin is, live facts, quick start, and a
  command crib pointing at `hermes -h`, `hermes gateway`, `hermes model`. The
  Overview gains a **code intelligence card**: when the user has `prowl-agent`
  installed and an indexed repo, the daemon surfaces doctor finding counts,
  files/symbols, and top hotspots (read-only exec, cached, degrades to hidden;
  prowl stays user-installed because upstream ships no license yet). New API:
  `/api/hermes/skills`, `/api/hermes/memory`, `/api/prowl`, `/api/prowl/search`,
  `/api/about`; the chat WebSocket learns models/commands/history/usage frames.
  Hermes onboarding detection now reads the mapping-form `model:` block, and
  session titles surface correctly.
- `shell/quickshell/launcher` + `rashin/backend`: a quick-ask answer is now a
  launch point, not a dead end. The answer text is selectable (mouse-copy any
  fragment), and `/api/ask` returns an `actions` array of entities the daemon
  detected in the answer and verified against the machine: real files, real
  directories, `http(s)` URLs, backtick commands whose first word is on
  `PATH`, and hex colors. The launcher renders each as a chip that does the
  obvious thing (file opens in nvim, folder in the file manager, URL in the
  browser, command and color copy with a live swatch), plus COPY for the whole
  answer and CONTINUE IN DASHBOARD. Chips walk with the arrow keys and fire
  with ENTER, typing re-asks, and copyables flash COPIED. Nonexistent paths
  and non-runnable spans are dropped so a chip never lies.
- `rashin/backend`: quick asks got fast. `/api/ask` now runs **two lanes**: a
  fabric-style fast lane makes ONE direct streaming chat-completions call on
  the same model connection hermes is configured with (openrouter, openai,
  groq, ollama, or any local endpoint; key read from `~/.hermes/.env`), a
  terse pattern prompt plus the vault maps as context, no Python spawn, no
  agent loop, answers in a second or two; the model replies `TOOLS_REQUIRED`
  when the ask genuinely needs tools, which escalates it to the session lane.
  OAuth backends (openai-codex) go straight to the session lane, and the
  daemon now **pre-warms the hermes session at boot**, cutting the first ask
  on this machine from ~19s to ~8s. The lane's connection is overridable in
  `rashin.json` (`quick.model` / `quick.baseUrl` / `quick.keyEnv`) for a
  cheaper or local quick-answer model. The ask CLI is now a thin pipe over
  `/api/ask`, both lanes land in the shared transcript, and consecutive
  duplicate working markers are deduped.
- `shell/quickshell/launcher` + `rashin/backend`: the launcher learns to ask
  the agent. A `\` prefix routes to Rashin: type `\why is my mic quiet?`,
  ENTER, and a pulsing strip names what hermes is doing (the running tool,
  thinking, writing) until one deliberately terse answer renders inline,
  image results (image_gen, screenshots) previewing as thumbnails. It rides
  a new `ryoku-rashin ask` one-shot that joins the daemon's shared session
  over the chat WebSocket with a quick-mode preamble only the model sees,
  and streams `@working`/`@perm`/`@answer` markers to stdout. Because it is
  the same session, the new CONTINUE IN DASHBOARD button opens the exact
  conversation, already on screen: the chat hub now keeps a per-session
  transcript (capped at 400 frames) and replays it to every joining client,
  which also means refreshing the dashboard no longer blanks the chat. A
  pending tool approval surfaces as APPROVE IN DASHBOARD. The `\` prefix
  joins the launcher help sheet.
- `rashin/systemd` + `rashin/backend` + `hyprland/modules/autostart`: the
  daemon now runs as a **systemd user unit** (`ryoku-rashin.service`) instead
  of riding the Hyprland session. `ryoku-rashin enable` does
  `systemctl --user enable --now`, so the dashboard is up at every login,
  survives compositor restarts, and restarts on crash; `enable --at-boot`
  adds `loginctl enable-linger` so it starts with the machine, before login.
  The unit runs `serve --if-enabled`, keeping `rashin.json` the single gate;
  without systemd everything falls back to the old detached spawn. The
  package ships the unit to `/usr/lib/systemd/user`, `deploy.sh` to
  `~/.config/systemd/user` (ExecStart rewritten to `~/.local/bin`), and the
  autostart.lua line is gone.
- `rashin/backend/web`: a **working strip** under the chat banner: while the
  agent acts, a pulsing dot names what it is doing live from the hermes
  stream (the running tool's title, `thinking`, `writing`, `waiting for your
  approval`), clearing at turn end and staying quiet during history replays.
  The hero and composer copy now call Rashin what it is, the needle (羅針),
  not the compass (羅針盤), whose 盤 is the dashboard itself.
- `rashin/backend` + `cli`: the vault gains two more generated layers, and the
  index follows the system. `ryoku-repo.md` is a **pre-indexed map of the Ryoku
  monorepo itself** (layout with file counts, key entry points, docs list),
  generated at package build by the `ryoku-rashin` PKGBUILD and shipped to
  `/usr/share/ryoku/rashin/ryoku-repo.md` (a dev `deploy.sh` writes the same
  snapshot to `~/.local/state/ryoku/rashin-repo.md`), so agents navigate the
  distro's source without a checkout. `user.md` is the **user-owned changes
  layer**: it hash-diffs the shipped base config against the live `~/.config`
  and lists override files, edited files, and removed files, reindexed
  separately by a 2-minute fingerprint watcher in the daemon whenever the
  user's config drifts. `ryoku update` now reindexes the vault after configs
  land on both channels (checkout and packaged), best effort, so the maps
  always describe the system that is actually running.
- `rashin/backend/web`: the dashboard scales to the viewport instead of hugging
  the left edge on wide screens: the content column centres (up to 1480px),
  and the hero, stat blocks, type, and chat art grow with `clamp()` between
  laptop and desktop sizes.
- `hub/quickshell/PerformancePage` + `shell/quickshell/{visualizer,pill,widgets}`:
  a **Performance Optimizations** section in Ryoku Settings, tweaks for modest
  hardware (most off by default; the visualiser freeze defaults on) and written to
  `~/.config/ryoku/performance.json` (watched live, no reload). Freeze the
  visualiser when no audio plays (it stops drawing at zero CPU and resumes on
  sound), unload the visualiser entirely when silent to free its ~190 MB of
  GPU/scene-graph memory (the daemon parks the process after a 30s silence grace
  and brings it back on audio, gated so a probe failure never drops the surface),
  freeze the pill bead's idle swirl, pause the desktop widgets' animation while
  windows cover them, and unload the widgets entirely once every screen is
  covered to free their ~250-400 MB (reloaded the moment an empty desktop
  returns). The visualiser also runs `cava` only while audio
  actually plays (default on), so a silent desktop no longer samples at 60fps for
  nothing.
- `hyprland/scripts/ryoku-cmd-game-mode` + `system/hardware/network` +
  `shell/quickshell/pill`: a one-click **Game Mode** in the Control Deck. A
  Utilities switch flips `Flags.gameMode`; the shell bridges it to the helper,
  which strips the compositor to its low-latency path through `hyprctl eval` (the
  Lua-parser path, since `hyprctl keyword` is rejected): no blur/shadow/rounding,
  animations off, `allow_tearing` with an immediate rule, and fullscreen-only VRR.
  It disables 802.11 power-save on every WiFi device (a pure latency win, with no
  reconnect and no throughput cap) via the privileged `ryoku-wifi-powersave`
  helper (`iw`), authorized passwordless by a polkit rule so the toggle stays one
  click, and pulls Do-Not-Disturb on. Fully reversible: `hyprctl reload` drops the
  eval overrides, the WiFi helper restores each device's prior power-save, and DND
  returns. Adds `iw` to the base set. Covered by `tests/game-mode.sh` and
  `tests/wifi-powersave.sh`.
- `shell/quickshell/plugins` + `hub/quickshell/PluginsPage`: a shell plugin
  system. A plugin ships a service + one adaptive `content/Widget.qml` (glyph /
  compact / full); the shell owns each host's layer, shape, size, and motion, so
  plugins read as native. v1 hosts: frame popout (fused into the frame blob in the
  pill) and desktop widget (the wallpaper layer). Discovery is
  `plugins/discover.sh` (catalogue + `~/.config/ryoku/plugins.json`), the
  signature kit is the `Ryoku.PluginKit` QML module (`plugins/kit`), placement is
  edited in Ryoku Settings -> Plugins and persisted by `ryoku-plugins-place`, and
  `ryoku-shell plugin <id>` toggles a frame popout. The legacy `wallhaven` plugin
  is reworked as the worked example. See `docs/plugins.md`.
- `hub/quickshell/GpuPage` + `hub/backend/gpu`: a System -> GPU page with a
  hardware-capability engine. Choose the graphics mode (Hybrid, Performance,
  Passthrough) and set up the optional GPU-passthrough stack, gated by checks (CPU
  virt, IOMMU, isolated dGPU group, which GPU drives the display, RAM, the virt
  stack) so it refuses anything unsafe. Dynamic vfio bind/unbind via a libvirt
  hook (no boot-time binding), kvmfr Looking Glass, swtpm + Secure Boot. The
  one-time "Enable passthrough" is reversible. Running virtual machines lives in
  the `apps/ryovm` app (quickemu/quickget), not the hub.
- `hyprland/binds` + `hyprland/resize`: working window resize. `Super + Ctrl +
  arrows` resize the active window directly (repeating); the `Super + R` resize
  mode also accepts `hjkl`, exits on `Super + R`, `Esc`, or `Return`, and shows a
  toast on entry, since entering a submap is otherwise silent.
- `hyprland/binds` + `hyprland/animations`: a scratchpad you can fill. `Super +
  Shift + H` stashes the active window into `special:scratch` as a tidy 1280x800
  centred float, `Super + H` toggles it, and a new `specialWorkspace` slide-and-fade
  drops it in.
- `shell/quickshell/sidebar` QuickStrip: a Night Light quick-toggle joins Do Not
  Disturb and Keep Awake, reading and toggling `hyprsunset` (the warm screen) live
  via the night-light script, so it stays in sync with the `Super + U` utility and
  the hub's Comfort tab.
- `hyprland/binds`: `Super + K` opens the keybind reference, the hub's live
  shortcut legend read from `binds.lua`, so the full shortcut list is one key
  away.
- `shell/quickshell/pill/Bar.qml` + `hub` (Shell -> Bar): an opt-in top bar, an
  alternative to the morphing pill island. The pill draws it inside the frame's
  own blob field, so the frame's top simply thickens into the bar (no separate
  program, no seam): the brand mark and workspace dots on the left, the clock in
  the centre (it opens the calendar), now-playing, the system tray and power on
  the right. Ryoku Settings -> Shell -> Bar turns it on, which hides the resting
  pill island so the two never overlap; surfaces still open from their keybinds
  and melt in and out of the bar centre. Default off.
- `shell/quickshell/switcher` + `hyprland/binds`: an Alt-Tab window switcher. A
  full-screen overlay (its own `qs -c switcher` instance, like ryoshot) lists the
  open windows in most-recently-used order as app-icon + title cards, opens with
  the previous window selected (hold Alt, tap Tab, release to switch back), and
  Tab or the arrows cycle, Enter or a click activates, Escape cancels. Bound to
  `Alt + Tab`; the frame and pill identity are untouched (separate overlay layer).
- `hyprland/themes/{washi,soft_color,mountains,crt,drift}`: five more theme rices.
  `washi` (warm vermilion on dark paper, clinical motion), `soft_color` (dreamy
  peach pastel on slate-blue), `mountains` (desaturated earth tones) and `crt`
  (cyan phosphor glow on near-black) ship fixed palettes; `drift` is a slow, airy,
  breathing look-only rice that follows the wallpaper. All opt-in from Ryoku
  Settings; the frame and island keep the Ryoku identity.
- `hyprland/themes/compact` and `hyprland/themes/glass`: two look-only rices
  (colours still follow the wallpaper). `compact` is dense and tight (small gaps,
  light rounding, no shadow, a soft pop); `glass` is heavy frosted blur with
  translucent windows and a gentle springy pop. Both opt-in from Ryoku Settings and
  keep the frame and island identity.
- `hyprland/themes/cassette`: a new flat, sharp, sepia theme rice (no blur or
  shadow, `rounding 0`, tight gaps) in a muted YoRHa/NieR palette, filling the gap
  left by the rounded, glassy default set. Opt-in from Ryoku Settings; the frame
  and island keep the Ryoku identity, and its fixed palette applies when colours
  are set to the theme rather than the wallpaper.
- `hyprland/monitors_user.lua.example`: a hand-written manual monitor override.
  `hyprland.lua` now `require`s `monitors_user` (a `pcall`, after the generated
  `monitors.lua`), so `~/.config/hypr/monitors_user.lua` wins and lets you force a
  mode, a custom modeline, position, scale, rotation, or mirror for a panel whose
  EDID is wrong (for example a fake/generic EDID). It is never shipped or
  overwritten, and `ryoku-monitor` leaves any output named in it alone.
- `hyprland/themes/`: full-system theme "rices", one folder each, with the look
  (`theme.json`), real Hyprland Lua (`init.lua`: motion and decoration finish), and
  a 16-colour `colors.json` for fixed palettes. Ships **default** (the shipped
  look), Tokyo Night, Aqua, Catppuccin, Gruvbox, Nord, and Rosé Pine. The active
  theme's `init.lua` is loaded by `hyprland.lua` (as `theme`) before `settings.lua`.
  Ryoku Settings applies them and toggles whether colours follow the wallpaper.
- `hyprland/hyprland.lua`: loads a generated `settings.lua` after the base modules
  and before `user.lua`, the override file Ryoku Settings writes. Missing by
  default (a `pcall` no-op); the hub creates it on first use. `window_rules` and
  the `Super + ,` legend now read "Ryoku Settings".
- `hyprland/hyprland.lua`: loads the runtime-generated drop-ins `gpu.lua` and
  `monitors.lua` with `pcall` (like `settings`, `theme`, and `user` already are),
  so a half-written or corrupt one -- which a crash or a GPU reset can leave behind,
  since those fire monitor events that rewrite `monitors.lua` -- falls back to
  Hyprland's defaults instead of dropping the whole config into emergency mode.
  `ryoku doctor` repairs the file and autoscale regenerates it on the next login.
- `hyprland/scripts/ryoku-cmd-nightlight`: `status`, `on [temp]`, and `off`
  subcommands (with the saved temperature persisted) so Ryoku Settings' Comfort
  tab can show and set the night light; the bare call still toggles for Super+U.
- `hyprland/modules/binds`: `Super + P` toggles the displays between mirror
  (duplicate) and extend, via `ryoku-monitor toggle`.
- `hyprland/modules/binds`: `Super + Tab` opens the pill's workspace switcher
  overview (`ryoku-shell workspaces`) for moving windows between workspaces.
- `hyprland/modules/binds`: `Super + M` toggles the desktop audio visualiser
  (`ryoku-shell visualizer`).
- `hyprland/modules/binds`: `Super + Shift + M` raises the visualiser over the
  windows on demand (`ryoku-shell visualizer-overlay`), flipping back to the desktop.
- `hyprland/modules/decoration`: a touch more room around tiled windows
  (`gaps_out` 24 -> 26, `gaps_in` 7 -> 8) for a clear frame-to-window vs
  window-to-window gap hierarchy that reads with the frame's new contact shadow.
- `hyprland/`: the Hyprland config in Lua, modular (entrypoint plus modules for
  input, decoration, animations, binds, window rules, ryoshot, and autostart)
  with hardware-managed gpu/keyboard/monitors. Launches the Ryoku shell and the
  laptop-only idle policy.
- `lockscreen/`: the vendored qylock clockwork theme, its installer, and the SDDM
  setup.
- `apps/`: kitty, fastfetch (with the branded wrapper), fish (greeting off),
  starship, and nautilus notes.
- `assets/`: the 力 brand logo and icons, plus the shipped wallpaper collection
  (`wallpapers/`) that installs to `~/Pictures/Wallpapers`; `ryoku-shell` picks a
  random one on first login.
- `shell/`: the Quickshell desktop UI (pill, sidebar, ryoshot),
  the wallust palette generation, the qt/kde theme, the user session target, and
  the `ryoku-shell` Go control-plane daemon (`ipc/`).
- `hyprland/` autostart and `shell/ipc`: apply wallust colors to
  OpenRGB-compatible keyboards and lighting devices through `ryoku-leds`.
- `hyprland/` autostart: set GTK apps to dark through `gsettings`
  (`color-scheme` prefer-dark, `gtk-theme` Adwaita-dark), so nautilus and other
  GTK apps match the dark Qt and kitty theme.
- `hyprland/` binds and autostart: tap ``Super+` `` to start Handy speech-to-text
  and the live mic wave, tap again to stop (`ryoku-shell voice`); autostart Handy hidden and
  tray-less (it is keybind-driven and configured from app search) when the
  optional `handy` binary is installed.
- `hyprland/` autostart: normalize the default microphone to unity gain on login
  through `ryoku-mic`, so an over-amplified codec does not clip Handy's recording
  or peg the voice wave.

### Changed
- `shell/quickshell/visualizer` + `hub/quickshell`: **the `line` visualiser
  style is now an oscilloscope** that draws the actual playback waveform, not a
  spectrum with sharp points. A new `Waveform` singleton captures the default
  sink's monitor (PipeWire-native, downsampled by `wavecap.py`) and the line
  traces it live: a glowing filament on a baseline that flatlines in silence and
  moves with the music, wearing the heart-monitor look as skin over a real music
  visualiser. Capture runs only while the style is selected and tears down with
  the surface. The Shell settings preview mirrors it and the style picker labels
  it "Monitor" (the `line` key is unchanged) (`Visualizer.qml`, `Waveform.qml`,
  `wavecap.py`, `VizPreview.qml`, `ShellSettingsPage.qml`).
- `shell/quickshell/{pill,widgets}`: the always-on shell layers render on demand
  (the basic Qt loop) instead of the threaded loop, which on NVIDIA spun the
  render thread every vsync whenever a live MultiEffect (card shadows, the bead
  glow) sat in the scene and burned idle CPU on a static desktop. On-demand
  rendering idles properly, roughly halving each layer's idle cost, with no
  visual change. Album art in the music island and OSD is now decoded at the
  thumbnail size instead of at full resolution.
- `hyprland/binds`: `Super + A` floats the active window at a fixed 1000x660,
  centred (press again tiles it back), instead of floating it at its current size.
- `hyprland/modules/binds`: reworked the keymap. `Super + arrow` keys move focus
  between windows and `Super + Shift + arrow` move the active window; `Super + 1..0`
  still focus workspaces but moving the active window there is now `Super + Alt + 1..0`.
  `Super + A` floats and centres the active window as a toggle (press again to tile
  it back), replacing the old `Super + A` / `Super + Shift + A` float/tile pair.
  `Super + R` enters a resize mode (`hyprland/modules/resize`, a submap where the
  arrows resize and Escape exits) and `Super + H` toggles the scratchpad (special
  workspace). `Super + arrow` no longer cycles workspaces (the number row does).
- `hyprland/modules/binds`: `Super + 1..0` now shows that workspace on the monitor
  under the cursor (the workspace is pulled to the focused monitor first) instead
  of yanking focus to wherever the workspace lived, so the number keys drive
  whichever screen the mouse is on rather than always the laptop. `Super + Alt +
  1..0` sends the active window to that workspace, on that screen.
- Tuned Hyprland window decoration and motion for the Ryoku shell: stronger
  shadows, softer translucency, wider breathing room, and branded open/close
  curves.
- Consolidated everything under a single `ryoku/` tree: the former top-level
  `shell/` now lives at `ryoku/shell/`, its modular Hyprland config replaced the
  old flat `ryoku/hyprland` (one Hyprland config now), and the duplicate
  `shell/fish` (with its non-brand greeting) was dropped for `ryoku/apps/fish`.

### Fixed
- `hyprland/modules/autostart.lua`: the first-run welcome walkthrough is no longer
  suppressed forever when it fails to launch. The launch chained `qs -c welcome`,
  `mkdir`, and `touch welcome-seen` with `;`, so the seen-flag was written even
  when `qs` exited without showing the tour, and the walkthrough never returned. It
  now gates the flag on `qs` succeeding (`&&`), so a first-boot launch failure
  retries on the next login instead of marking the tour seen.
- `hyprland/modules/autostart.lua`: booting a snapshot from the Limine menu now
  actually offers the one-click restore. limine-snapper-sync ships its restore
  prompt as an XDG autostart entry, but Hyprland runs no XDG autostart manager,
  so under Ryoku's own session the notification never fired and a user booted
  into a snapshot got no cue to restore it. Autostart now runs
  `limine-snapper-restore --notify` (command-gated); on a normal boot it
  detects no snapshot and exits silently.
- `hyprland/modules/autostart.lua`: the welcome tour's double-fire guard now
  actually guards. `flock -o` closes the lock fd before exec, releasing the
  lock the instant `qs -c welcome` starts, so two racing autostart fires could
  both open the tour; and the lock file lived at a fixed `/tmp` path one user
  owns, so on a multi-user box the second user's flock failed to open and their
  first-login tour was silently skipped (the seen-marker still got written).
  The `-o` is gone and the lock lives under `$XDG_RUNTIME_DIR`.
- `hyprland/modules/env.lua` + `shell/qt6ct`: app logos in the launcher's
  all-apps grid resolve again. `QT_QPA_PLATFORMTHEME` was `kde`, but the `kde`
  platform-theme plugin comes only from `plasma-integration` (a 122-package
  Plasma pull), which this Plasma-free desktop never installed, so Qt resolved
  no icon theme at all and searched hicolor only. Named freedesktop icons like
  the Avahi entries' `network-wired` fell back to the broken-image placeholder.
  Switched back to the `qt6ct` platform theme (its plugin ships with `qt6ct`,
  already in the base set) and ship `qt6ct/qt6ct.conf` with `icon_theme=`
  `Papirus-Dark` and the Fusion style. Removed the now-dead `kde/kdeglobals`:
  its KDE ColorScheme was equally inert without the missing plugin, and keeping
  its `[Icons]` line would duplicate the icon-theme source.
- `cli/doctor`: the limine-snapper-sync checks only run when limine is
  actually installed. A GRUB box with a healthy snapper setup (converted
  CachyOS installs, typically) was flagged inconsistent forever, with a fix
  suggestion that could not work there.
- `hyprland/hyprland.lua`: no more "Your config has errors" flash on a fresh
  first boot. Hyprland reports even a `pcall`'d `require()` of a missing module
  in the config-error overlay, and six optional drop-ins (`monitors_user`,
  `theme`, `settings`, `modules.private`, `ghosttype`, `user`) legitimately do
  not exist on a new home. The loader now probes with `package.searchpath`
  first and only requires files that are actually there.
- `shell/quickshell/{visualizer,pill,widgets}` + `shell/ipc`: a memory leak on this
  Qt 6.11 / NVIDIA stack where any continuously-animating or continuously-composited
  element grows RSS without bound (a plain rotating rectangle leaks ~0.9 MB/min and
  never settles; a frozen visualiser stays flat). Fixes: the visualiser idle wave
  freezes when silent by default (resuming instantly on audio); the pill bead is
  removed entirely (its 12fps idle-swirl Canvas was the worst pill offender) and the
  WaveMeter held static; and the desktop widgets, which ride the wallpaper and are
  invisible whenever a window covers every screen, are unloaded there by the daemon
  and reloaded the instant an empty desktop returns (they otherwise kept rendering
  and ran a day's uptime past 1.5 GB). Active content animates as before.
- `shell/quickshell/pill`: opening a pill surface that grabs the keyboard (the
  control deck, launcher, clipboard, calendar, ...) and closing it left the
  previously focused window un-typeable. The pill is one always-mapped layer that
  toggles its keyboard focus Exclusive while a surface is open and None when it
  closes; Hyprland leaves the keyboard on the released layer (the window still
  reports as active, so a plain refocus is a no-op) until a real focus change.
  On close the shell now hands focus back to the active window by bouncing off the
  next window and refocusing it. A launched app still wins (it maps and grabs
  focus via focus_on_activate after the handback). Verified live with synthetic
  keystrokes: typing is dead after closing the deck without the fix and restored
  with it, and the launcher still focuses the app it launched.
- `hub/backend/qemu`: a windowed VM booted to the UEFI shell / PXE ("failed to
  load Boot0002 ... Not Found", then "Start PXE over IPv4") instead of the
  installer ISO, even with the ISO correctly attached. OVMF boots by its own
  persistent NVRAM order (`*_VARS.fd`) and ignores `-boot order=dc`; that NVRAM
  goes stale (a boot entry pointing at a device that no longer exists) and falls
  through to PXE. Attach the disk and ISO as explicit devices with `bootindex`
  (ISO 1, disk 2), which QEMU passes via fw_cfg and OVMF honours over its saved
  order, so the ISO boots deterministically. Fixes it on already-affected VMs
  without wiping their NVRAM. Verified live: reproduced the PXE screen with the
  real config, then booted Void to the desktop with the same stale NVRAM.
- `hyprland/modules/misc`: a newly opened or re-raised window (notably Discord and
  Vivaldi) sometimes came up un-typeable until you moved it to another monitor or
  reopened it. The modular config refactor had silently dropped the `misc`/`xwayland`
  block, reverting `focus_on_activate` to its `false` default, so an app's
  xdg-activation focus request was ignored whenever the window landed off the focused
  workspace/monitor; `follow_mouse = 2` then removed the pointer fallback that had
  been masking it. Restores the block as a dedicated module: `focus_on_activate = true`,
  `xwayland.force_zero_scaling` (crisp Chromium/Electron on HiDPI/fractional displays),
  and `disable_hyprland_logo`.
- `hyprland/scripts/ryoku-cmd-mirror`: the webcam mirror (力 deck -> Tools) ran at
  5-15 fps and stuttered because mpv negotiated the camera's raw YUYV stream, which
  is USB-bandwidth capped (about 5 fps at 1080p, 10 at 720p). It now asks the camera
  for MJPEG when it offers it (probed with ffmpeg, falling back to the default so a
  raw-only camera still works), restoring the full 30 fps, and renders explicitly
  through `--vo=gpu-next` (libplacebo) so a stray software `vo` in mpv.conf can't
  bog it down.
- Hyprland: DPI autoscale now re-runs when a display is hotplugged, not only at
  login, so an external monitor plugged in mid-session is positioned and scaled
  immediately instead of coming up at 1x until the next relogin.
- Hyprland: a monitor connected mid-session now gets the current wallpaper painted
  onto it automatically. The hotplug handler repaints every output (via `ryoku-shell
  wallpaper refresh`) once autoscale has settled the new mode, so the screen no
  longer comes up on a black background until the next manual wallpaper change.
- Hyprland: the NVIDIA VA-API/GLX env hints (`LIBVA_DRIVER_NAME`,
  `__GLX_VENDOR_LIBRARY_NAME`, the `__GL_*` toggles) were set on every machine,
  breaking hardware video decode and Xwayland GL on AMD and Intel. They now
  apply only when the NVIDIA driver is present; mesa auto-detects elsewhere.
- Hyprland: a window stranded in maximize when a Chromium/Electron app leaves
  page fullscreen (a spurious mode-1 event on exit) is reset to normal, so the
  window returns to its original size instead of staying expanded.
- `hub`: the Shell settings subtabs (Frame, Island, Bar, Visualizer) centred their
  content in the panel, so short tabs dropped their controls into the middle with a
  large empty gap above. The tab content top-aligns now.
- `hub/backend` (`gpu caps`) + `hub/quickshell/GpuPage`: the System -> GPU page
  could sit on "Detecting..." forever. `ryoku-hub gpu caps` shelled out to the
  GPU detector with no time limit, so a wedged host probe (a runtime-suspended
  or stuck `nvidia-smi`) hung the whole call and the page never resolved. The
  caps call now runs under a hard timeout (its own process group, killed on
  expiry so an orphaned probe can't hold the pipe open), and the page surfaces a
  failed or timed-out probe with a Retry instead of an endless spinner.
- `shell/deploy.sh` + `hub/backend` (`gpu caps`): a dev deploy installed
  `ryoku-hub` but not `ryoku-gpu`/`ryoku-gpu-detect`, so the hub called a stale
  detector that predates `detect --json` and prints its table; the parser then
  failed with a cryptic "invalid character 'C'". Deploy now installs the GPU
  detector alongside the hub (fixing both the GPU page and autostart pinning),
  and `gpu caps` reports an out-of-date `ryoku-gpu` plainly instead of leaking
  the parser error. Retry clears the prior failure so it visibly re-checks.
- `hub/backend` (`vm setup`, `gpu apply`) + `hub/quickshell/GpuPage`: "Install
  QEMU" reported success even when pacman failed (the install ran best-effort and
  the "Done" line printed unconditionally), so the page kept asking to install.
  The install now propagates pacman's exit status, verifies `qemu-system-x86_64`
  is actually present, and on failure points at `ryoku update`; the passthrough
  enable aborts the same way instead of writing config over a failed install. The
  Machine tab also re-checks on its own while the install runs, so it advances
  without a manual Recheck.
- `hub/backend` (`vm`, qemu) + `hub/quickshell/GpuPage`: a windowed VM failed to
  start on some machines and left a window that could not be closed. It rendered
  through host GL (`virtio-vga-gl` + `gtk,gl=on`), whose EGL path is brittle under
  Wayland and depends on the host GPU, so it opened on one GPU and failed to start
  on another. It now uses 2D `virtio-vga` in a plain GTK window: no host GL,
  identical on AMD, NVIDIA and Intel, and a picture for every guest (installers
  included). OVMF firmware is detected across edk2 layouts instead of one
  hardcoded path, and a launch that dies is reported with QEMU's log tail (and the
  VM is detected as running, so Stop works) instead of a silent "failed to start".
- `hyprland/modules/input`: a newly opened window was not active until the mouse
  moved onto it. `follow_mouse = 1` refocuses whatever the pointer sits over, so a
  window spawned away from the cursor lost focus at once. `follow_mouse = 2`
  detaches keyboard focus from the pointer: a new window keeps focus, and a click
  moves it.
- `hyprland/hyprland.lua`: a broken optional drop-in says so in the log. An
  `optional()` module that exists but fails to load (a syntax error in a
  hand-edited `user.lua` or `monitors_user.lua`) was swallowed whole, so the
  user's edits silently did nothing; the pcall error is now printed, naming
  the module and the parse failure, while the config still degrades instead
  of hitting the emergency overlay.
