# ryoku-shell

Install the Ryoku desktop on an existing Arch machine, without the ISO.

```bash
curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/ryoku-shell-installer/install.sh | bash
```

Headless / unattended:

```bash
curl -fsSL .../install.sh | bash -s -- --yes
```

Preview without changing anything:

```bash
curl -fsSL .../install.sh | bash -s -- --dry-run
```

## What it does

`install.sh` is a dumb bootstrap: it verifies the machine is Arch-based
x86_64, downloads the prebuilt `ryoku-shell-install` binary (checksummed) from
this directory, and hands it the real terminal. Everything else is the binary,
a bubbletea TUI sharing the ISO installer's visual language:

1. **Scan** the machine: distro, GPU, display manager, network stack, rival
   quickshell shells (Noctalia, DankMaterialShell, Caelestia, iNiR),
   conflicting user daemons (dunst/mako/waybar/swww/…), a niri setup to
   migrate from, an Omarchy install to retire (repo + mirror pin), keyboard
   layout, btrfs.
2. **Plan** review with per-item toggles (NVIDIA drivers, SDDM switch,
   NetworkManager switch, rival-shell removal, AUR extras, fish shell).
3. **Install**, streamed step by step:
   legacy-repo retirement → `pacman -Syu` → tools → sparse payload clone → config backup (with a
   generated `restore.sh`) → `[ryoku]` repo + keyring trust → conflict removal
   → desktop packages → GPU drivers → SDDM/qylock/network wiring →
   `ryoku materialize` + seeds (wallpapers, brand, keyboard layout salvaged
   from the old setup) → AUR extras → `ryoku doctor` → verify.

Afterwards the machine is a normal Ryoku box: `ryoku update` updates it
forever, `ryoku doctor` heals it, and the `[ryoku]` pacman repository signs
everything. Nothing here ever needs re-running.

Migration policy: rival shells are uninstalled (toggle), conflicting daemons
are disabled but never uninstalled, the old display manager is disabled (not
removed), niri stays installed as a fallback session, and every config the
install touches is saved to `~/.local/state/ryoku/shell-install/backup-<ts>/`
first, `restore.sh` included.

## Development

```bash
go build -trimpath -o ryoku-shell-install .   # rebuild
sha256sum ryoku-shell-install > ryoku-shell-install.sha256
go test ./...
```

The binary and its checksum are committed (same convention as
`installation/tui/ryoku-tui`) so `install.sh` can fetch them from
raw.githubusercontent.com with no release infrastructure. Test a branch with:

```bash
curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/<branch>/ryoku-shell-installer/install.sh \
  | RYOKU_SHELL_REF=<branch> bash
```

`--payload /path/to/checkout` (or `RYOKU_SHELL_PAYLOAD`) skips the payload
clone and uses a local repo, for iterating without pushing.
