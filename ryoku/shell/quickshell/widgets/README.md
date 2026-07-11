# Desktop widgets

These are the clock, weather, and calendar that sit on the wallpaper. It's all
plain QML reading one JSON file. There's no framework hiding under it, and I'd
like to keep it that way, so if you're about to add something clever, check first
that the dumb version doesn't already do the job.

`qs -c widgets` loads `shell.qml`. The daemon keeps it alive (it's the `widgets`
entry in `ipc/daemon.go`'s `components` list), same as the pill and the
visualiser. One layer per monitor, parked below your windows. After you change a
file, `ryoku-shell reload` or the "Reload shell" row in the right-click menu picks
it up.

## How it's laid out

    shell.qml          the layer per screen: hosts the slots, the grid, the menu
    WidgetSlot.qml     placement + drag + the backing card; wraps one widget
    WidgetGrid.qml     the snap grid that fades in while you drag
    WidgetMenu.qml     the right-click menu (desktop scope + per-widget scope)
    CornerTicks.qml    the little L-brackets, same idea as the pill's dossier
    Singletons/
      Config.qml       the one source of truth: ~/.config/ryoku/widgets.json
      Theme.qml        tokens: fonts, brand, the ink ramp, the carbon surface
      Wallust.qml      the live palette read off the wallpaper
      Now.qml          one second-tick everyone shares
      WeatherData.qml  the Open-Meteo fetch
      Events.qml       the shared calendar store, watched (see Calendar sync)
    clock/             Clock.qml picks a face; the faces + date strips live here
    weather/           Weather.qml picks a design; skies + day cells live here
    calendar/          Calendar.qml picks a face; the faces + lib live here
                       (month, minimal, agenda, week, heat)

A widget is two halves on purpose. The dispatcher (`clock/Clock.qml`,
`weather/Weather.qml`, `calendar/Calendar.qml`) is glue: it reads which design is
selected, shows it, and reports its own size up to the slot. The designs
(`ClockDigital`, `WeatherCard`, `CalMonth`, `SkyRain`, and the rest) are the
thing you actually see, and they read the
singletons straight (`Now.date`, `Wallust.accent`, `Config.clockSeconds`). I
didn't thread props down through three layers; a design reaches for what it needs
the way the visualiser does. You can open any one design file and understand it
without chasing five others.

## What it should look like

Three jobs, two looks, and I don't want them blurred together.

**The widgets sit on the wallpaper, so they stay bright and quiet.** Text is the
cool near-white from `Theme.ink`, and the slot drops a soft shadow behind a bare
widget so it reads on a light photo as well as a dark one. Reach for `Wallust`
when you want colour (the clock accent, the weather condition word), because the
whole point is that the desktop retunes with the wallpaper. The brand orange
(`Theme.brand`) is the one fixed accent; spend it on a single mark, not a surface.
If you find yourself hardcoding a colour that should follow the wallpaper, stop.

A few things I hold to when drawing one of these:

- Size comes from a scale number, never `Item.scale`. Scaling a rendered item
  blurs the text. Each design multiplies its own font sizes and dimensions by
  `Config.<widget>Scale` and reports `implicitWidth`/`implicitHeight` so the slot
  can place and pad it. Look at `ClockDigital` if you want the pattern. On the
  desktop you resize by dragging the bracket at a widget's bottom-right corner,
  which just scrubs that scale.
- Keep the design simple and let type, spacing, and motion carry it. The faces
  are deliberately plain. If a design needs a key to be understood, it's too busy.
- Motion is short and means something. Use `Behavior` plus a `NumberAnimation`
  with an easing you actually chose, and match the timings already in the file
  next door. Let it rest when nothing's happening (the weather sky has an
  `animate` flag for exactly this); don't leave a timer spinning on an idle
  desktop.
- One design per file. The dispatcher flips a `Loader` between them.

**The chrome is a different animal.** The right-click menu follows the pill's
carbon-dossier look, because it's a floating bit of shell and should feel like the
same desktop as the pill, not a popup from some other app. That means the cool
carbon surface (`Theme.cardTop`/`cardBot`), `CornerTicks` framing it, hairline
rules between groups, the 力 mark in the masthead, mono uppercase micro-labels,
and the vermilion accent showing up as a thin hover tick instead of a filled
blob. If you build more widget chrome later (a config popover, say), build it like
this. Don't hand me a rounded grey context menu.

## Adding a face (clock, weather, or calendar)

1. Drop a new file in `clock/`, `weather/`, or `calendar/`. Make it an `Item`,
   read the singletons it needs, set `implicitWidth`/`implicitHeight`.
2. Register it in the dispatcher's `switch` (`Clock.qml` / `Weather.qml` /
   `Calendar.qml`) and add the key to the design list the menu cycles through in
   `WidgetMenu.qml` (`cycleDesign`).
3. Add the option to the design dropdown in the hub
   (`ryoku/hub/quickshell/WidgetsPage.qml`).
4. If you want it in the hub's live preview, mirror it in `ClockPreview.qml` /
   `WeatherPreview.qml` / `CalendarPreview.qml`. Those are hand re-implementations,
   not the real designs, because the hub is a separate `qs` config and can't
   import these files. It's duplication and I know it; it's the same trade the
   visualiser's `VizPreview` makes. Keep the faces simple and the mirror is cheap.

A calendar face that lets you type (the add field) also has to expose an
`editing` bool that's true while its field holds focus. The dispatcher bubbles it
up, `WidgetSlot` re-exposes it, and `shell.qml` raises the layer's keyboard grab
off it (the same grab the plugin tiles and the launcher use). A display-only face
(like `CalMinimal`) just leaves `editing` unset.

On a face with an add field (month, week, agenda, heat) the whole grid is live.
Click a day to pick it; click a note to load it back into the add field for
editing (Enter replaces it in place on its own day, Esc drops back to adding).
The delete × arms on the first tap and only removes on the second, so a stray
click can't lose a note, and an empty day says so instead of leaving a bare gap.
Navigation is an offset from today, never an absolute month, so it can't drift:
prev/next step the view, a `TODAY` chip shows up once you've moved and jumps
back to the current month/week/page, and the view re-homes on its own at the
midnight rollover. `CalMinimal` stays display-only.

## The menu and the hub, and how they actually connect

This is the part people get wrong, so plainly: the menu and the
hub never call each other. There is no IPC between them. They both read and write
one file, `~/.config/ryoku/widgets.json`, and meet there. The host's `Config`
singleton watches that file, so whoever wrote last, the running widgets follow on
the next file event. That's the whole connection.

`Config.qml` is the contract. Every setting is an alias over the `JsonAdapter`
plus a default, and there are four little writers the desktop side uses:

    Config.set("dateShow", false)          // set one key, write the file
    Config.toggle("clockSeconds")          // flip a bool, write the file
    Config.setAnchor("clock", "top-left")  // snap to a zone
    Config.setFree("weather", 480, 320)    // pin a dragged x/y

The menu calls those and nothing else. A row like "Date On/Off" is just
`Config.toggle("dateShow")`. Snapping in the 3x3 pad is `Config.setAnchor(...)`.
Dragging a widget on the desktop ends in `Config.setFree(...)` from `WidgetSlot`.

The hub edits the same file, but it's a form with Save and Revert, so it keeps its
own draft and writes on a throttle (see `WidgetsPage.qml`). The catch worth
remembering: the hub holds its own copy of the whole schema. If you add a key to
`Config.qml` and forget to add it to the hub, a Save over there can clobber the
key it never knew about. So a new knob lands in two places, every time.

### Opening the hub from the menu

There's no "show me this page" call. You ask the hub's Go backend to remember the
section, then launch the hub:

    Quickshell.execDetached(["sh", "-c",
        "ryoku-hub config set section widgets; flock -n -o /tmp/ryoku-hub.lock qs -c hub"])

`ryoku-hub config set section widgets` writes the hub's TOML so it opens on the
Desktop Widgets page, and the `flock` is the same guard the `Super + ,` keybind
uses so you don't get two hub windows. The section name ("widgets") has to be a
real entry in the hub's `Hub.qml` `sectionDefs`, or it'll fall back to the
default page. "Reload shell" is the plain version of the same trick:

    Quickshell.execDetached(["ryoku-shell", "reload"])

### Adding a knob end to end

Say you want a new toggle that both the menu and the hub can flip. The loop:

1. `Config.qml`: add the alias, the `JsonAdapter` property, and a sensible
   default.
2. `WidgetsPage.qml`: add the key to `keys`, to the `draft` object, to its
   `JsonAdapter`, and to `defaults`, then add a control that calls
   `page.edit("yourKey", v)`. (Yes, four spots. That's the price of the Save form.)
3. The design or the slot reads `Config.yourKey`.
4. Optional: a `MenuRow` in `WidgetMenu.qml` that calls `Config.set`/`Config.toggle`.

That's it. No new wiring, no new file format, no signal plumbing. Everything goes
through the one JSON file, which is the only reason this stayed small.

## Calendar sync (shared with the pill)

The calendar's notes are the same store the pill's calendar uses:
`~/.local/state/ryoku/events.json`, with the model in `calendar/lib/events.js`.
There's no IPC; both surfaces are separate `qs` processes that meet at that one
file, the same way the menu and the hub meet at `widgets.json`.

`Singletons/Events.qml` is the thin wrapper: `add`/`update`/`remove` mutate the in-memory
array and write the file (`atomicWrites`), and the `FileView` is `watchChanges`,
so a note added on the desktop reloads into the pill and back. Writing our own
file fires the watch too, but the reload runs on the resulting `onLoaded` (after
the buffer refreshes), so re-reading our own write is idempotent, not the stale
read the pill used to guard against by not watching at all.

`events.js` and its node test are duplicated from `pill/lib/` on purpose (a
self-contained config, the same trade `weather/lib/weather.js` makes); keep the
two copies identical. `calendar/lib/cal.js` is the month-grid geometry (offsets,
row counts, week-of), also node-tested. Both run under `node` because they never
touch QML, `Date.now()`, or `Math.random()`.

## Things I left dumb on purpose

- The layer takes pointer input across the whole wallpaper now, so a right-click
  lands anywhere. It still sits below your windows, and the desktop catcher in
  `shell.qml` only accepts the right button, so a left click on bare wallpaper
  does nothing rather than getting eaten in a way that feels off.
- Placement is either a compass zone or `"free"`. Zones use a fixed edge margin
  so they survive a monitor swap; free is raw pixels from a drag. Dragging sets
  the anchor to `"free"`; the snap pad sets it back to a named zone.
- One weather fetch for the whole machine. `shell.qml` binds `WeatherData.unit`
  once at the top; every monitor's widget reads the same singleton.
- The calendar ships off by default; clock and weather are the two that show on a
  fresh desktop. Turn it on in Settings or the right-click menu.
- `WidgetSlot`'s drag grip sits UNDER the widget, so the calendar's day cells and
  add field keep their own clicks while bare chrome still drags. Clock and weather
  have no interactive children, so the whole surface still drags for them.
