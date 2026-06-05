# Third-party code: Ambxst

The contents of this `ambxst/` subtree are integrated Ryoku code originally
derived from the **Ambxst** desktop shell (import roots re-rooted from `qs.*`
to `qs.ambxst.*`, and `Quickshell.shellDir` paths redirected into this
subdirectory). The directory mirrors Ambxst's upstream root layout
(`config/`, `modules/`, `assets/`, `scripts/`) so its relative paths resolve.

- Upstream: https://github.com/Axenide/Ambxst
- Vendored at commit: `989d923ff324693a2aadae12770a7bce6679d992`
- License: **GNU AGPL-3.0** — see `LICENSE` in this directory.

## License obligation (important)

This code is licensed under the GNU Affero General Public License v3.0. Unlike the
MIT-licensed `noctalia/` vendor, AGPL is a strong copyleft: this vendored subtree —
**and any modifications to it** — remains under AGPL-3.0, including the Section 13
"Remote Network Interaction" source-availability obligation. Modifying the look and
feel does not relicense it. The bundled `LICENSE` is the upstream AGPL-3.0 text and
must travel with this code.

Only the subset needed for the dynamic-island content (dashboard, default view,
notifications and their service/theme/component dependencies) was vendored.
