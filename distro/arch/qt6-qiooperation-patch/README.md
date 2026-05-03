# qt6-qiooperation-patch

Workaround for a Qt 6.11.0 use-after-free that crashes the iNiR / Ryoku
shell whenever clicks toggle a layer-shell surface on niri.

## Symptom

Click rapidly in the empty space on the right side of the topbar (between
weather and the bluetooth/wifi cluster, or the very top-right corner) →
the bar greys out and niri shows "Config reloaded". Under the hood
`inir.service` has died with one of:

- `pure virtual method called` → `terminate called without an active exception` → `SIGABRT`
- Plain `SIGSEGV`

systemd respawns the shell ~5 seconds later, and `services/GameMode.qml`
sed-edits `~/.config/niri/config.d/60-animations.kdl` and runs
`niri msg action reload-config` ~1 second into startup, which is the
"config reloaded" toast the user sees. The niri reload is a *consequence*
of the crash, not the cause.

## Root cause

Two stacked bugs surfaced by the same trigger.

### Trigger

Clicking the empty area on the bar's right side toggles
`GlobalStates.sidebarRightOpen`. The `SidebarRight` PanelWindow flips
`visible` on/off in response, which maps and unmaps the Wayland
layer-shell surface. niri responds to every (re)map by sending
`wl_surface.preferred_buffer_scale` so the client knows the surface's
preferred scale. Qt's Wayland plugin synthesises a
`WindowDevicePixelRatioChangedEvent` for each one, even when the value
hasn't actually changed.

```
QtWaylandClient::QWaylandWindow::setScale         qwaylandwindow.cpp:1557
  → QWindowSystemInterface::handleWindowDevicePixelRatioChanged
  → ... event delivery ...
  → QQuickWindow::event(QEvent*)                  qquickwindow.cpp:1672
  → emit physicalDpiChanged()                     qquickwindow.cpp:405
  → updatePixelRatioHelper recursive walk         qquickwindow.cpp:394
```

### Bug 1, Qt 6.11.0 destructor calls a virtual on `this`

`QIOOperation::~QIOOperation()` (qtbase/src/corelib/io/qiooperation.cpp:42,
brand new in Qt 6.11) calls `ensureCompleteOrCanceled()`, which dispatches
through `QRandomAccessAsyncFilePrivate::cancelAndWait(this)`. By the time
the base destructor runs, all the derived destructors
(`QIOVectoredWriteOperation`, `QIOReadWriteOperationBase`) have already
executed and the vtable has been swung back to `QIOOperation`'s. The
virtual dispatch lands on a pure-virtual entry → `__cxa_pure_virtual` →
`std::terminate` → SIGABRT.

Textbook "don't call virtuals from a destructor" anti-pattern.

### Bug 2, UAF in the recursive item-tree walk

Independent of bug 1, `updatePixelRatioHelper` recurses through
`item->childItems()` for every item in the tree. During that walk, some
item ends up being freed (likely tied to async file I/O cancellation
during the DPR update). When the recursion later dereferences the freed
item pointer, SIGSEGV.

Bug 1 was actually masking bug 2: the `__cxa_pure_virtual` happened
*early* in the recursion, before the walk got deep enough to hit the
freed pointer.  Patching out bug 1 just unmasked bug 2.

## Fix layers

This workaround applies **two layers of defense**:

### Layer 1, `SidebarRight.qml` keeps its surface mapped

Patches `modules/sidebarRight/SidebarRight.qml` so the PanelWindow
**never sets `visible = false`**.  The surface stays mapped at all times.
Visibility is controlled by:

- The existing slide animation, which already hides content visually.
- A new mask region that swaps between two real Items
  (`Region { item: open ? _fullMask : _emptyMask }`), `_fullMask` covers
  the whole panel when open (so widgets and click-outside-to-close both
  receive input); `_emptyMask` is a 0×0 Item when closed so clicks fall
  through to whatever is underneath.

This kills the trigger at the source: niri stops emitting
`preferred_buffer_scale` on every sidebar toggle because there's no
(re)map happening.

The patch is reapplied on every install via
`install/config/ryoku-shell-branding.sh::apply_sidebar_right_keep_mapped_workaround`,
so updates that overwrite the runtime shell tree don't lose it.

### Layer 2, patched `libQt6Core.so.6.11.0`

Even with Layer 1, any *other* surface lifecycle (notifications, OSDs,
control panel, etc.) could in principle reach the same code path.  As
defence-in-depth, this directory ships a binary patch of
`libQt6Core.so.6.11.0` that NOPs out the two
`call ensureCompleteOrCanceled` instructions inside `~QIOOperation` (the
regular and deleting destructors, both 5 bytes each).  The QObject base
destructor still runs; only the buggy pre-cleanup virtual dispatch is
skipped.

Tradeoff: any in-flight async file op outliving its `QIOOperation` no
longer gets its `cancelAndWait`. Worst case is a tiny per-op leak that
the OS reclaims when the process exits, fully ignorable in practice.
The shell never crashes from this path.

The patched lib lives at `~/.local/lib/qt6-fix/libQt6Core.so.6.11.0` and
is wired into `inir.service` via `LD_LIBRARY_PATH` in a systemd drop-in.
**System-wide Qt is untouched**, every other Qt app on the box uses
the unpatched `/usr/lib/libQt6Core.so.6`.

## Usage

```bash
# install both fix layers
./apply.sh

# verify everything is in place
./verify.sh

# undo
rm ~/.config/systemd/user/inir.service.d/qt6-qiooperation-patch.conf
rm -rf ~/.local/lib/qt6-fix
systemctl --user daemon-reload
systemctl --user restart inir.service
```

The Layer 1 QML patch is removed by reverting / reinstalling iNiR (the
patch lives in `install/config/ryoku-shell-branding.sh`; comment the
`apply_sidebar_right_keep_mapped_workaround` invocation in `main()` to
disable it on the next install).

## Surviving updates

- **`pacman -Syu` bumps `qt6-base`**: the system `libQt6Core.so.6.11.0`
  is replaced. `inir.service` keeps using our patched copy at
  `~/.local/lib/qt6-fix/`. **However**, when Qt eventually moves to
  6.11.x with x>0, the file name will change (`.so.6.11.1` etc.) and
  the destructor offsets may shift. Rerun `apply.sh`; it reads the
  current system lib's offsets via the constants at the top of the
  script. If the destructor was rearranged, the script aborts with a
  clear message, regenerate via:

  ```bash
  objdump -d --disassemble='_ZN12QIOOperationD0Ev' /usr/lib/libQt6Core.so.6
  objdump -d --disassemble='_ZN12QIOOperationD1Ev' /usr/lib/libQt6Core.so.6
  ```

  Look for the `e8 ?? ?? ?? ??  call <ensureCompleteOrCanceled>` line in
  each.  Update `OFFSET_REGULAR_DTOR`, `OFFSET_DELETING_DTOR`, and the
  matching `EXPECTED_*_BYTES` constants in `apply.sh`.

- **iNiR shell update**: the install script under
  `install/config/ryoku-shell-branding.sh` reapplies the SidebarRight
  patch. If the upstream `SidebarRight.qml` is rewritten enough that the
  perl pattern stops matching, the install logs a warning and the patch
  silently no-ops, re-derive the perl substitution against the new
  upstream layout.

## Upstream status

When Qt fixes the bug in 6.11.x or 6.12, retire this directory. The fix
likely lives in either:

- `qiooperation.cpp::~QIOOperation()`, move the virtual call out of the
  base destructor (e.g. into derived destructors or a non-virtual
  helper).
- The DPR-event delivery path, early-return in `setScale` when the
  scale hasn't actually changed, which would prevent the redundant
  tree walk that triggers the UAF.

Track at <https://bugreports.qt.io/> with keywords `QIOOperation`,
`ensureCompleteOrCanceled`, `updatePixelRatioHelper`,
`physicalDpiChanged`.
