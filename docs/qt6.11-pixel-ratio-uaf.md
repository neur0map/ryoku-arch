# Qt 6.11.0 pixel-ratio UAF, investigation log

**Status:** mitigated.
**Affected:** any Quickshell-based shell on Wayland with Qt 6.11.0.
**First diagnosed:** 2026-05-03 (commit/branch `niri-inir-transition`).
**Fix layers:**

- `distro/arch/qt6-qiooperation-patch/`, binary patch of `libQt6Core.so.6.11.0`,
  scoped to `inir.service` via `LD_LIBRARY_PATH`.
- `install/config/ryoku-shell-branding.sh::apply_sidebar_right_keep_mapped_workaround`,
  QML patch keeping the right-sidebar surface mapped at all times.

## Symptom

Click rapidly in the empty space on the right side of the topbar (between
weather and the bluetooth/wifi cluster, or the very top-right corner) →
the bar greys out and niri toasts "Config reloaded". `inir.service` has
exited with one of:

- `pure virtual method called` → `terminate called without an active exception` →
  `code=dumped, status=6/ABRT`
- Plain `code=dumped, status=11/SEGV`

systemd respawns the shell after ~5 seconds.  The shell's own
`services/GameMode.qml` runs a 900 ms startup timer that `sed`-edits
`~/.config/niri/config.d/60-animations.kdl` and runs `niri msg action
reload-config`, which is what produces the niri "config reloaded" toast.
**The niri reload is a consequence of the crash, not a cause.**

`coredumpctl list` showed dozens of consecutive aborts, all in
`/usr/bin/quickshell`, alternating between SIGABRT and SIGSEGV.

## Investigation timeline

### 1. False lead, `IpcHandlerRegistry` UAF

iNiR 2.24 ships a Quickshell patch (`patches/quickshell/fix-extension-uaf.patch`)
fixing a known UAF in `EngineGeneration::destroy()` where extensions
(including `IpcHandlerRegistry`) were freed before the QML root.  Arch's
stock `quickshell` 0.2.1-6 doesn't carry the patch.  The shell's own
systemd unit even sets `LimitCORE=0` and `Environment=QS_DISABLE_CRASH_HANDLER=1`
to suppress the resulting crash dumps.

Hypothesis: this was the bug.  **Mitigation built**:
`distro/arch/quickshell-ryoku/`, a PKGBUILD that wraps Arch's
`quickshell` 0.2.1-6 with the iNiR patch applied.  Installed as a
drop-in (`provides=(quickshell)`, `conflicts=(quickshell)`).

**Verified via `strings /usr/bin/quickshell | grep "Ryoku Arch"`**: the
patched binary was correctly running.

**Result: did not fix the crash.**  Aborts continued on every click
storm.  Hypothesis discarded.

### 2. Stack trace via coredump

The systemd unit's `LimitCORE=0` was suppressing all coredumps, hiding
the actual call stack.  Override with:

```ini
# ~/.config/systemd/user/inir.service.d/coredump-debug.conf
[Service]
LimitCORE=infinity
```

Then `coredumpctl info <pid>` finally yielded a usable backtrace,
which immediately invalidated the `IpcHandlerRegistry` hypothesis.

The crashing chain (full backtrace via `gdb` against
`/var/lib/systemd/coredump/core.qs.*.zst`, debug symbols streamed from
`https://debuginfod.archlinux.org`):

```
Trigger: niri sends wl_surface.preferred_buffer_scale on layer-shell surface map

#42 wl_closure_invoke                          wayland-1.25.0/src/connection.c:1243
#37 QtWayland::wl_surface::handle_preferred_buffer_scale
#36 QtWaylandClient::QWaylandWindow::setScale  qwaylandwindow.cpp:1557
#35 QWindowSystemInterface::handleWindowDevicePixelRatioChanged
#30 QWindowPrivate::updateDevicePixelRatio     qwindow.cpp:1449
#29 QCoreApplication::sendEvent                qcoreapplication.cpp:1549
#26 QQuickWindow::event(QEvent*)               qquickwindow.cpp:1672
#25 emit QQuickWindow::physicalDpiChanged()    qquickwindow.cpp:405
#24-#1  updatePixelRatioHelper recursion       qquickwindow.cpp:394
#0  updatePixelRatioHelper                     [SEGV, item=<freed pointer>]
```

The recursion is Qt's normal item-tree walk to dispatch
`itemChange(ItemDevicePixelRatioHasChanged)` to every QQuickItem.

### 3. Bug 1, Qt 6.11.0 destructor calls a virtual on `this`

`QIOOperation` is a brand-new class hierarchy in Qt 6.11.0
(`qtbase/src/corelib/io/qiooperation.cpp`).  Its base destructor:

```cpp
QIOOperation::~QIOOperation()
{
    ensureCompleteOrCanceled();      // line 42
}

void QIOOperation::ensureCompleteOrCanceled()
{
    Q_D(QIOOperation);
    if (d->state != ...::Finished) {
        if (d->file) {
            auto *filePriv = QRandomAccessAsyncFilePrivate::get(d->file);
            filePriv->cancelAndWait(this);   // virtual dispatch on `this`
        }
    }
}
```

By the time `~QIOOperation()` runs, all derived destructors
(`QIOVectoredWriteOperation`, `QIOReadWriteOperationBase`) have already
executed; the vtable has been swung back to `QIOOperation`'s.  The
virtual dispatch from `cancelAndWait(this)` lands on a pure-virtual
entry → `__cxa_pure_virtual` → `std::terminate` → SIGABRT.

Textbook "don't call virtuals from a destructor" anti-pattern, freshly
introduced in 6.11.

### 4. Bug 2, UAF in the recursive walk itself

After patching out bug 1 (NOPing the `call ensureCompleteOrCanceled` at
both destructor entry points), the SIGABRTs stopped, but **the SEGVs
continued**, now reaching frame ~26 in the recursion before crashing.
Disassembly of `updatePixelRatioHelper` at the crash address showed it
faulting on a child item dereference.

So the underlying bug is independent: **the QQuickItem tree is being
mutated during the DPR-change walk**, leaving a stale pointer for the
recursion to chase.  Bug 1 was masking bug 2 by aborting earlier.

The mutation almost certainly comes from
`QQuickItemPrivate::itemChange(ItemDevicePixelRatioHasChanged)` reaching
some custom QQuickItem subclass (Quickshell or QtQuick.Controls) that
reacts by tearing down a child or async resource.  We didn't pin the
exact item, the patched-libQt6Core mitigation kept the SIGABRTs at bay
long enough to confirm bug 2 was real, but bug 2 turned out to be
fixable at a higher layer.

### 5. The trigger

Both bugs only fire when the DPR-change walk runs.  That walk is
triggered by `wl_surface.preferred_buffer_scale` from niri.  niri emits
that event on every layer-shell surface (re)map, even when the scale
hasn't changed (the user's display is integer 1× scale, so the value is
always the same).

Clicking the empty space on the bar's right side toggles
`GlobalStates.sidebarRightOpen` → `SidebarRight` PanelWindow flips
`visible` on/off → Wayland surface maps/unmaps → niri emits the event
→ Qt walks the tree → boom.

## Mitigation

### Layer 1 (primary), keep the surface mapped

Patch in `install/config/ryoku-shell-branding.sh` (function
`apply_sidebar_right_keep_mapped_workaround`).  The PanelWindow now:

- Sets `visible: true` declaratively and never sets `visible = false`.
- Adds two mask geometry Items, `_fullMask` (anchors.fill: parent) and
  `_emptyMask` (0×0), and selects between them via
  `mask: Region { item: open ? _fullMask : _emptyMask }`.
- Keeps the existing slide animation, which already hides content
  visually when `_sidebarShown = false`.

Important gotcha: do **not** use `Region { item: null }` for the open
state.  Quickshell's `Region` interprets `null` as "no input region"
in this code path, which makes the sidebar contents non-clickable AND
prevents the backdropClickArea from firing close-on-click-outside.
The fix uses a real sized Item (`_fullMask`) for the open state.

niri stops emitting `preferred_buffer_scale` on every sidebar toggle
because the surface stays mapped.  The DPR-change cascade no longer
fires.  This is the fix that actually solved the user-reported
reproduction.

The patch is reapplied on every iNiR install/update, so future
upstreams that overwrite the runtime shell tree don't lose it.

### Layer 2 (defence-in-depth), patched libQt6Core

`distro/arch/qt6-qiooperation-patch/apply.sh` copies
`/usr/lib/libQt6Core.so.6.11.0` into `~/.local/lib/qt6-fix/` and
NOPs out the two `call ensureCompleteOrCanceled` instructions
(`e8 ?? ?? ?? ??` → `0f 1f 44 00 00`) in `~QIOOperation`'s regular and
deleting destructors.  Wired into `inir.service` via a systemd drop-in
that adds `LD_LIBRARY_PATH=$HOME/.local/lib/qt6-fix` plus pinned
`QT_PLUGIN_PATH` / `QML_IMPORT_PATH` (otherwise Qt rebases its plugin
search to the fix dir and can't find `libqwayland.so` or
`qtquickcontrols2plugin`).

System Qt is untouched; every other Qt app uses
`/usr/lib/libQt6Core.so.6` as normal.

This catches any *other* surface lifecycle that might still emit DPR
events, notifications, OSDs, control panel, screen-corner panels,
none of which Layer 1 covers.

## Why both layers?

Layer 1 alone fixes the user's specific reproduction but not
hypothetical other triggers.  Layer 2 alone fixes bug 1 (SIGABRT) but
leaves bug 2 (SIGSEGV) live, just rarer.  Together they make the shell
crash-free against this entire class of issue.

If we only had to keep one: **Layer 1**. It eliminates the trigger
itself rather than papering over the consequence.  Layer 2 is
no-runtime-cost insurance.

## Pre-mortem checks pre-fix

Things tried first that *didn't* work, in case anyone retraces:

- `quickshell-ryoku` (the iNiR `fix-extension-uaf` patch).  Different
  bug.  Verified via `strings /usr/bin/quickshell | grep "Ryoku Arch"`.
- `LD_PRELOAD` shim overriding `QIOOperation::ensureCompleteOrCanceled`.
  Doesn't work, symbol has `STV_PROTECTED` visibility, intra-DSO calls
  bypass GOT/PLT.  Confirmed via `readelf -W --dyn-syms`.
- Downgrading `qt6-base` to 6.10.x.  Heavy-handed (touches every Qt6
  app), and the Arch repo no longer hosts 6.10 packages, would need
  the Arch Archive.  Not pursued.
- Full `qt6-base` rebuild from PKGBUILD with a one-line C++ patch.
  ~30 min build.  User declined ("no big build, don't break inir").

## Reproducing the diagnosis

```bash
# 1.  Re-enable coredumps for inir.service
mkdir -p ~/.config/systemd/user/inir.service.d
cat > ~/.config/systemd/user/inir.service.d/coredump-debug.conf <<'EOF'
[Service]
LimitCORE=infinity
EOF
systemctl --user daemon-reload
systemctl --user restart inir.service

# 2.  Reproduce the crash (rapid clicks on empty bar right side)

# 3.  Read the latest stack trace
sudo pacman -S --needed gdb
coredumpctl info <pid>      # journal-stored summary
cd /tmp
coredumpctl dump <pid> -o core.<pid>
DEBUGINFOD_URLS=https://debuginfod.archlinux.org gdb -batch -nx \
    -iex 'set debuginfod enabled on' \
    -ex 'thread apply 1 bt 35' \
    /usr/bin/quickshell core.<pid>
```

## Upstream status

Track at <https://bugreports.qt.io/> with keywords `QIOOperation`,
`ensureCompleteOrCanceled`, `updatePixelRatioHelper`,
`physicalDpiChanged`, or `preferred_buffer_scale`.

When Qt fixes either:

- the destructor (move the virtual call out of the base, e.g. into a
  non-virtual helper or each derived destructor), or
- the DPR-event delivery path (early-return in
  `QWaylandWindow::setScale` when the scale hasn't actually changed,
  which would prevent the tree walk entirely),

retire the corresponding mitigation layer.  The `SidebarRight` keep-
mapped patch can stay regardless, it's a small efficiency win that
avoids reallocating the layer surface on every toggle.
