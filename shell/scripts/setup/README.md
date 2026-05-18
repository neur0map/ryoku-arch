# Setup Recipes

Setup recipes are one-shot shell scripts exposed as searchable global actions.
They live in `shell/scripts/setup/` and are discovered by `_scan.sh`.

Each public recipe is a `*.sh` file whose name does not start with `_`.
GlobalActions reads the metadata header and exposes an action named
`setup-<slug>`.

Required metadata:

```bash
# @meta name: Setup Example
# @meta description: Describe what this recipe configures
# @meta icon: construction
# @meta keywords: example setup install
```

Recipes should source `_lib.sh`, call `setup_init`, report progress with
`setup_progress`, finish with `setup_done`, and end with `setup_finish_pause`
when launched in a terminal.

Use Ryoku helper commands when available, especially `ryoku-cmd-present` and
`ryoku-pkg-add`, so recipes keep the same package behavior as the rest of
Ryoku.
