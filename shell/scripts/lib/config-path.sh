#!/usr/bin/env bash

# Library file: intended to be sourced by other scripts.
# Do not set shell options here; callers own execution mode.

# Canonical Ryoku config directory is ~/.config/ryoku-shell.
# Legacy installs used ~/.config/illogical-impulse.
#
# Compatibility policy:
# - If legacy dir exists as a real directory, keep using it.
# - If legacy is a symlink and new dir exists, use new dir.
# - If only one exists, use that one.
# - If none exists, default to new dir.

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

RYOKU_SHELL_CONFIG_DIR_NEW="${XDG_CONFIG_HOME}/ryoku-shell"
RYOKU_SHELL_CONFIG_DIR_OLD="${XDG_CONFIG_HOME}/illogical-impulse"

ryoku_shell_config_dir() {
    # Legacy symlink -> new (post-migration steady state)
    if [[ -L "$RYOKU_SHELL_CONFIG_DIR_OLD" && -d "$RYOKU_SHELL_CONFIG_DIR_NEW" ]]; then
        printf '%s\n' "$RYOKU_SHELL_CONFIG_DIR_NEW"
        return
    fi

    # Legacy real directory wins for backwards compatibility.
    if [[ -d "$RYOKU_SHELL_CONFIG_DIR_OLD" ]]; then
        printf '%s\n' "$RYOKU_SHELL_CONFIG_DIR_OLD"
        return
    fi

    # New path when legacy is absent.
    if [[ -d "$RYOKU_SHELL_CONFIG_DIR_NEW" ]]; then
        printf '%s\n' "$RYOKU_SHELL_CONFIG_DIR_NEW"
        return
    fi

    # Fresh install default.
    printf '%s\n' "$RYOKU_SHELL_CONFIG_DIR_NEW"
}

ryoku_shell_config_file() {
    printf '%s/config.json\n' "$(ryoku_shell_config_dir)"
}

ryoku_shell_version_file() {
    printf '%s/version.json\n' "$(ryoku_shell_config_dir)"
}

ryoku_shell_installed_marker_file() {
    printf '%s/installed_true\n' "$(ryoku_shell_config_dir)"
}

ryoku_shell_migrations_state_file() {
    printf '%s/migrations.json\n' "$(ryoku_shell_config_dir)"
}
