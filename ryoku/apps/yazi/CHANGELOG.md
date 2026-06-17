# Changelog: ryoku/apps/yazi/

## Unreleased

### Added
- `yazi.toml` ported from upstream Ryoku, adapted for the slim Arch build: the
  `edit` opener runs Neovim directly (`nvim "$@"`, `block = true`) instead of the
  upstream-only `ryoku-launch-editor` helper, so nvim takes over yazi's terminal.
  The `[open]` prepend rules still route `text/*`, `application/json`,
  `application/xml`, and `*.toml/json/kdl/yml/yaml/conf` files to that opener.
