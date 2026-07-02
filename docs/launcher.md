# The launcher

The launcher is the Ryoku command palette: a standalone, centered overlay
summoned with `Super + Space`. It searches and launches apps, calculates, runs
system actions, manages clipboard and snippets, switches windows, searches the
web, finds files, installs packages, controls any media player, and searches and
plays free music from YouTube Music. It is a full rebuild of the old pill
app-list, dropped from the pill so it has the room a Raycast/Alfred-class palette
needs.

It lives in `ryoku/shell/quickshell/launcher/`, a Quickshell component supervised
by the `ryoku-shell` daemon (a peer of `pill`/`sidebar`), kept warm so it opens
instantly and toggles with `ryoku-shell launcher`.

## Anatomy

- `shell.qml` the layer-shell overlay window (namespace `launcher`), resident and
  hidden at rest, shown on the focused monitor. Toggled over the daemon socket
  with an IPC fallback. Blurred backdrop via the `launcher` layer rule in
  `hyprland/modules/decoration.lua`.
- `Launcher.qml` the card body: the search row over the rest dashboard (empty
  query), the all-apps grid (`Ctrl+A`), the action-mode tabs (`/` prefix), or the
  ranked result list. Grows and shrinks on the Ryoku morph curve.
- `SearchRow.qml` the 力 glyph, the query field, a result counter, and the
  Google-Lens + music-recognition buttons.
- `ResultList.qml` / `ResultGrid.qml` / `NowPlaying.qml` / `RestDashboard.qml` the
  views. `ActionPanel.qml` is the per-item verb sheet (`Ctrl+K`); `CategoryTabs.qml`
  is the action-mode tab bar.

## Providers

Each capability is a provider: its own folder under `providers/<name>/`, a single
QML component implementing the `Provider` contract (`providerId`, optional
`prefix`, `query(text) -> rows`). The `Dispatcher` singleton routes a prefixed
query to one provider and fans an unprefixed one across the default set, merged by
score. Adding a provider is a folder plus one line in `providers/Providers.qml`;
the dispatcher discovers it by registration, never by an edit to the routing.

| Provider | Prefix | What it does |
|---|---|---|
| apps | (default), `>` | launch desktop apps, fuzzy + launch-frequency ranked |
| calc | `=`, leading digit | qalc: math, units, currency |
| actions | `/` | system actions (lock, wallpaper, screenshot, night light, media keys, settings) in category tabs |
| clipboard | `;` | cliphist history, copy or delete |
| windows | (default) | switch Hyprland windows |
| web | `?` | web search with `!bang` site shortcuts, plus an inline DuckDuckGo instant answer |
| files | (default, 3+ chars) | fd file search, open or reveal |
| snippets | (default) | text expander (`{date}`/`{clipboard}`/`{selection}`/`{cursor}`) + quicklinks (`{query}`) |
| packages | `install`/`remove`/`search` | GPK across every package manager |
| mpris | (default, media words) | now-playing + transport for any player, plus **YT Radio** (seed a YouTube Music radio from whatever is playing) |
| ytmusic | `@`, pasted YT link | YouTube Music search (InnerTube), pasted track/playlist/mix links, endless radio playback (mpv), saved playlists |
| script | per-script keyword | run rofi-script / dmenu scripts |
| rashin ask | `\` | one terse question to the Rashin agent (hermes): a pulsing strip names what it is doing (tool, thinking, writing), then the answer renders as selectable text over action chips. The daemon detects entities in the answer and each becomes a chip: real files open in nvim, folders in the file manager, URLs in the browser, shell commands and hex colors (with a live swatch) copy to the clipboard, plus COPY for the whole answer and CONTINUE IN DASHBOARD. Chips walk with the arrow keys and fire with ENTER; typing re-asks. Needs Rashin enabled; see `rashin.md` |

Ranking and protocol logic live as testable JavaScript in `lib/` and each
provider's folder (`fuzzy.js`, `dispatch.js`, `rofiscript.js`, `wave.js`,
per-provider parsers), each with a `.test.mjs` run by `node`.

## Music

YouTube Music is Ryoku's built-in free-music source, and the launcher is its
front door: search a track and it plays inline, then keeps going as an endless
radio. The engine and the full behaviour (queue, radio auto-extend, the
system-audio bridge) are documented in `docs/ryotunes.md`; this is the launcher
surface for it.

- **YouTube Music** (`@`): searches YouTube Music's keyless InnerTube API with
  curl and shows proper songs (clean title/artist/album and square album art in
  the row, no second cover lookup). A prefix cache makes refining a query feel
  instant; if InnerTube is unreachable it falls back to a yt-dlp flat search so
  results never disappear. Picking a track hands off to the RyoTunes engine
  (`Singletons/Radio.qml`): mpv streams it (audio only) and an endless YouTube
  Music radio auto-extends behind it. Needs yt-dlp and mpv (with mpv-mpris); the
  provider hides itself when they are absent. A signed-in default browser lifts
  yt-dlp's rate limit through `--cookies-from-browser`.
- **Any player** (mpris): the now-playing row controls whatever is playing
  (Spotify, a browser tab, an app) with play/pause/next/prev. When it is not our
  own stream it also offers **YT Radio**, which seeds an endless YouTube Music
  radio from that track's title and artist, so any system audio turns into free
  music. Our stream yields to other players by fading out and pausing, so two
  streams never stack.
- The now-playing card on the rest screen shows album art, title/artist, elapsed
  and total time, an up-next peek while our radio plays, and the signature wavy
  seekbar (a sine that animates only while playing); the fill advances off a
  500ms MPRIS position poll. A live cava wave sweeps behind it while a track
  plays, gated so the analyser runs only while the launcher is open and something
  is playing. When our radio owns playback the card uses its exact square cover;
  for another player with no cover (some browsers) it fetches one from the
  keyless iTunes Search API by artist and title (noise-stripped for a better hit).

## Extending it

- **Scripts** (no code): drop a `{ keyword, name, exec }` entry in
  `~/.config/ryoku/launcher-scripts.json`. The script speaks the rofi-script /
  fuzzel dmenu protocol (newline rows, `\0key\x1fvalue` directives,
  `ROFI_RETV`/`ROFI_INFO` env), so existing rofi/fuzzel scripts work unchanged.
- **Snippets / quicklinks**: `~/.config/ryoku/launcher-snippets.json` and
  `launcher-quicklinks.json`.
- **A native provider**: add `providers/<name>/<Name>.qml` (a `Provider`), register
  it in `providers/Providers.qml`. Shell-backed providers run their process async
  with a debounce and call `Dispatcher.notifyAsync()` when results land.

## Performance

The launcher is one resident process. While open it has no RAM ceiling (album-art
decode, mpv, blur). At rest it sheds the heavy work: no media process runs until a
track is played, the clipboard is read on demand (not watched), and file/package
searches only fork past a length gate. Keystroke-to-result never animates; the
motion budget is spent on the window show/hide and the action-panel open
(`Singletons/Motion.qml`).

## Theming

Colors, spacing, and motion are tokens in `Singletons/{Theme,Metrics,Motion}.qml`;
components read them, never hardcoded values. With Settings -> Shell -> Match
wallpaper on, `Theme` resolves to the live wallust palette (the same `shell.json`
flag and `colors.json` the rest of the shell uses), so the launcher recolors with
the system theme.
