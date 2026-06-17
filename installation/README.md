# installation/

Everything needed to get Ryoku onto a computer: the live ISO, the guided
installer, and the backend that does the real work.

## What's here

- `iso/` The archiso profile that builds the live image. It boots straight into
  the installer.
- `tui/` The installer itself: a full-screen terminal app that walks you through
  keyboard, locale, time zone, network, hardware, disk, user, and encryption,
  then hands off to the backend.
- `backend/` `ryoku-install`: the script the TUI calls to partition the disk, set
  up encryption, format and mount, install the base system, and configure Limine.
  It reads its answers from the TUI through `RYOKU_*` variables, so it can also
  run unattended.

## The flow

1. The machine boots the ISO and logs in automatically.
2. The installer starts and collects your choices.
3. On confirm, it runs `ryoku-install` with those answers.
4. `ryoku-install` partitions, installs, and configures the system, then offers
   to reboot.

Nothing is written to disk until you confirm on the review screen.
