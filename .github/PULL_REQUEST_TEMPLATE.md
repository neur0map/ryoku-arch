<!-- Keep one logical change per pull request. See CONTRIBUTING.md. -->

## What changed

Describe the change and why it is needed.

## Area

<!-- The commit subject area: global | installation | system | ryoku | docs | test | tooling | release -->

## How it was tested

Describe how you verified this on a running system, not only that it parses.

## Checklist

- [ ] One logical change, with a clear `[area] scope: summary` commit subject.
- [ ] Matching `CHANGELOG.md` updated in the area I touched.
- [ ] The git hooks pass locally; I did not use `--no-verify`.
- [ ] Lua parses (`luac -p`), shell scripts pass `bash -n`, and QML passes
      `qmllint` where applicable.
- [ ] No duplicated config, no dead code, no commented-out code, no em-dash.
- [ ] Docs updated if behavior or layout changed.
