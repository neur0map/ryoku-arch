# The launcher

The launcher is the Ryoku command palette: a standalone, centered overlay
summoned with `Super + Space`. It searches and launches apps, calculates, runs
system actions, manages clipboard and snippets, switches windows, searches the
web, finds files, installs packages, and controls and searches music (Spotify and
YouTube Music). It is a full rebuild of the old pill app-list, dropped from the
pill so it has the room a Raycast/Alfred-class palette needs.

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
| mpris | (default, media words) | now-playing + transport for any player |
| spotify | `s:` | Spotify catalog search + play (Web API) |
| ytmusic | `@` | YouTube Music search + play (yt-dlp + mpv) |
| script | per-script keyword | run rofi-script / dmenu scripts |

Ranking and protocol logic live as testable JavaScript in `lib/` and each
provider's folder (`fuzzy.js`, `dispatch.js`, `rofiscript.js`, `wave.js`,
per-provider parsers), each with a `.test.mjs` run by `node`.

## Music

The launcher is the *quick* music path: search a track and play it inline. The
full music experience, a play queue with YouTube Music radio auto-extend,
playlists, playlist import, and source switching, lives in the RyoTunes deck
(`Super+M`); see `docs/ryotunes.md`. Both share the same daemon-owned backend.

- **Spotify**: the MPRIS provider controls the running Spotify client (play,
  pause, skip, now-playing) with zero setup. Catalog search, library, and queueing
  go through the Spotify Web API via `ryoku-shell spotify` (PKCE OAuth, token under
  `$XDG_STATE_HOME/ryoku`). Connect once with
  `ryoku-shell spotify auth <client-id>` (a Spotify developer app with the redirect
  `http://127.0.0.1:15298/callback`); playback commands need Premium.
- **YouTube Music**: the `@` prefix searches with yt-dlp and streams the picked
  track with mpv (audio only); `mpv-mpris` exposes that mpv over D-Bus so the
  now-playing card and the MPRIS transport verbs control it just like any other
  player. Needs yt-dlp and mpv (with mpv-mpris); the provider hides itself when
  they are absent. A signed-in default browser lifts the rate limit through
  `--cookies-from-browser`. The stream yields automatically: while it plays it
  watches MPRIS and stops the moment another player (Spotify, a browser tab, any
  app) starts, so two streams never overlap.
- The now-playing card on the rest screen shows album art, title/artist, elapsed
  and total time, and the signature wavy seekbar (a sine that animates only while
  playing); the fill advances off a 500ms MPRIS position poll. A live cava wave
  sweeps behind it while a track plays, gated so the analyser runs only while the
  launcher is open and something is playing. When the player exposes no cover (an
  mpv or yt-dlp stream, some browsers), the card fetches one from the keyless
  iTunes Search API by artist and title.

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
