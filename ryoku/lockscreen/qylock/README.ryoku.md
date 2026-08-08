# Vendored qylock (trimmed)

Upstream: https://github.com/Darkkal44/qylock
Vendored at commit: cde4d11e9e3d385620becdc877a0521e40a55e47

Only the assets Ryoku ships are kept here so the greeter installs **offline**
(no git clone at install time): the `clockwork` SDDM theme and the
`quickshell-lockscreen`. The full upstream repo carries ~35 themes with large
video backgrounds (1.2G) which Ryoku does not use. Licensed under the upstream
LICENSE in this directory.

The vendored core skin carries `themes/clockwork/orbital/preview.gif`, the
dark-mode segment of upstream `Assets/clockwork.gif`. Optional skins and their
catalogue previews are owned by `ryoku-extras`; they are not duplicated here.

The in-session shim diverges from upstream in one place to keep the lock usable
with every skin: `quickshell-lockscreen/shim/SddmShim.qml` (plus the matching
`keyboard` export in `lock_shell.qml`). Upstream omits `sddm.hostName`, so every
skin's `isQuickshell` test is true; skins like `material-you` and `nothing` gate
login and power behind `!isQuickshell`, leaving their password field, reboot, and
shutdown dead under the in-session lock. The shim now reports a real `hostName`
(making `isQuickshell` false), implements `sddm.suspend()`, and exposes SDDM's
`keyboard` object (skins assign `keyboard.numLock`). Everything else is upstream
verbatim.
