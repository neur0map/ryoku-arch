# qt6-qiooperation-patch

This directory is retained as a retired Qt workaround reference. It is not part
of the current Hyprland/Ryoku-shell workstation path and should not be installed
on new systems.

## Current Status

The active Ryoku shell should run without this binary Qt drop-in. If a future
Qt regression appears, reproduce it against the current shell service and
runtime paths before reusing anything here:

```bash
env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST qs list --all
systemctl --user status ryoku-shell.service --no-pager
ryoku-doctor shell
```

Do not wire this patch into `ryoku-shell.service` without a fresh crash trace
that proves the current shell is hitting the same Qt destructor path.

## Files

- `apply.sh`: archived binary patch helper.
- `verify.sh`: archived verification helper.
- `libQt6Core.so.6.11.0.patched`: archived patched library payload.

## Retirement Rule

Prefer deleting this directory once no packaging, support, or rollback workflow
references it. Until then, keep documentation clear that it is archival and not
a supported current workstation fix.
