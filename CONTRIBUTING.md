# Contributing

Ryoku is early, so the best contributions are focused and easy to verify.

## Before Opening A PR

- Keep changes scoped to one behavior or one doc area.
- Follow the style rules in `AGENTS.md`.
- Include a short verification note: commands run, hardware tested, or why a check was not applicable.
- Do not rewrite unrelated files or generated assets.

## Good First Areas

- hardware install reports
- documentation fixes
- theme polish
- Quickshell UI bugs
- security-tooling baseline suggestions with rationale

## Issues

Use issues for reproducible bugs. Use discussions for ideas, screenshots, tool suggestions, and broader design feedback.

## Maintainer Mode

If you are running Ryoku Arch on this machine and are committing changes
to the install-time patches (`install/config/ryoku-shell-branding.sh`,
`distro/arch/qt6-qiooperation-patch/`, ...), opt in to the drift check
once per clone:

```bash
git config --local ryoku.devmode true
```

The pre-commit hook then verifies your live system actually has each
patch applied before letting the commit through. Catches the common
mistake of committing a tweak you forgot to reinstall.

Bypass for one commit:  `RYOKU_DEV_SKIP=1 git commit ...`
Disable permanently:    `git config --local --unset ryoku.devmode`
Force-enable per shell: `RYOKU_DEV=1`

Contributors not running Ryoku do nothing. The check skips silently by
default.
