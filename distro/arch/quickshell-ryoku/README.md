# quickshell-ryoku

Drop-in replacement for the official Arch `quickshell` package, carrying the
Ryoku project's `fix-extension-uaf.patch`.

## Why

`quickshell` 0.2.1 (Arch repo, all `pkgrel`s through at least `-6`) ships an
unpatched `EngineGeneration::destroy()` that frees extensions, including
`IpcHandlerRegistry` and its `QHash`, *before* the QML root is destroyed.
The root is scheduled via `deleteLater()`, so it tears down later in the event
loop. During that teardown, lazy singleton instantiation can call
`PostReloadHook::componentComplete()`, which dereferences the already-freed
registry through a dangling pointer in the extensions hash.

Ryoku documents this in `patches/quickshell/README.md` upstream:

> Simpler shells rarely hit this because they have few singletons and no
> uninstantiated components at reload time. Ryoku's panel family system (ii vs
> waffle) and 50+ IPC handlers make the race virtually guaranteed.

Symptom in practice: rapid clicks on the bar's right side (or anything that
churns Loaders/Components) eventually trigger one of:

- `pure virtual method called` → `terminate called without an active exception`
  → `SIGABRT` (heap reuse landed the freed slot on an abstract base vtable)
- `SIGSEGV` in `IpcHandlerRegistry::registerHandler()` (heap stayed unmapped)

Ryoku's stock `ryoku-shell.service` masks both with `LimitCORE=0` and
`Environment=QS_DISABLE_CRASH_HANDLER=1` so the disk doesn't fill with 45–90 MB
crash reports, but the shell still respawns through systemd's restart loop.

## Build & install

```bash
cd distro/arch/quickshell-ryoku
makepkg -si
```

The package `provides=(quickshell=0.2.1)` and `conflicts=(quickshell)`, so
pacman will swap it in. Restart the Ryoku shell to pick up the new binary:

```bash
systemctl --user restart ryoku-shell.service
```

## Keeping it pinned

`pacman -Syu` will try to replace it with the upstream `quickshell` whenever
Arch bumps `pkgrel`. Either:

- Add to `/etc/pacman.conf`:

  ```ini
  [options]
  IgnorePkg = quickshell
  ```

- Or rebuild this PKGBUILD whenever upstream bumps, syncing the `pkgver` /
  `pkgrel` / `sha256sums` from
  <https://gitlab.archlinux.org/archlinux/packaging/packages/quickshell/-/raw/main/PKGBUILD>
  and re-checking that the patch still applies (the bug is in
  `src/core/generation.cpp::EngineGeneration::destroy()`, confirm before
  rolling forward).

## Upstream patch status

Tracked at <https://git.outfoxxed.me/quickshell/quickshell>. When the fix
lands upstream and Arch bumps to a `pkgver` that includes it, retire this
package.

## Related, different crash, similar symptoms

If after installing this package you *still* see `pure virtual method
called` aborts or SIGSEGVs while clicking the bar, you're hitting a
*separate* Qt 6.11.0 use-after-free in `QIOOperation::~QIOOperation`
that this PKGBUILD doesn't address (it's in Qt, not Quickshell).  See
`distro/arch/qt6-qiooperation-patch/` and
`docs/qt6.11-pixel-ratio-uaf.md` for that fix.
