# Vendored qylock (trimmed)

Upstream: https://github.com/Darkkal44/qylock
Vendored at commit: cde4d11e9e3d385620becdc877a0521e40a55e47

Only the assets Ryoku ships are kept here so the greeter installs **offline**
(no git clone at install time): the `clockwork` SDDM theme and the
`quickshell-lockscreen`. The full upstream repo carries ~35 themes with large
video backgrounds (1.2G) which Ryoku does not use. Licensed under the upstream
LICENSE in this directory.

One file the upstream skin dirs do not carry is added per skin:
`themes/clockwork/<skin>/preview.gif`, the looping thumbnail the Ryoku Settings
lock-screen picker shows. Orbital's is the dark-mode segment of upstream
`Assets/clockwork.gif`; tape's is rendered from the skin itself (upstream ships
no tape preview). Everything else here is upstream verbatim.
