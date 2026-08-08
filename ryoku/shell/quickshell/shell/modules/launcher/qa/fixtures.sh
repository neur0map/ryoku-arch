#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
state="${QA_FIXTURE_STATE:?QA_FIXTURE_STATE must name the private fixture state}"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
state_home="${XDG_STATE_HOME:-${HOME}/.local/state}"
app_dir="${data_home}/applications"
xbel="${data_home}/recently-used.xbel"
launcher_config_dir="${config_home}/ryoku"
launcher_state_dir="${state_home}/ryoku"
recent_path="/tmp/ryoku-launcher-qa-recent.txt"

fixture_name() {
    printf 'ryoku-launcher-qa-actions-%s.desktop' "$1"
}

desktop_backup() {
    printf '%s/desktop-%s.original' "$state" "$1"
}

stash_file() {
    local path="$1"
    local key="$2"
    if [[ -e "$path" || -L "$path" ]]; then
        mv -- "$path" "$state/${key}.original"
    else
        : >"$state/${key}.absent"
    fi
}

restore_file() {
    local path="$1"
    local key="$2"
    rm -f -- "$path"
    if [[ -e "$state/${key}.original" || -L "$state/${key}.original" ]]; then
        mkdir -p "$(dirname "$path")"
        mv -- "$state/${key}.original" "$path"
    fi
    rm -f -- "$state/${key}.absent"
}

write_desktop_fixture() {
    local count="$1"
    local target
    local ids=""
    local index
    target="${app_dir}/$(fixture_name "$count")"

    for index in $(seq 1 "$count"); do
        ids+="Option${index};"
    done

    {
        printf '[Desktop Entry]\n'
        printf 'Type=Application\n'
        printf 'Name=Ryoku QA Options %s\n' "$count"
        printf 'GenericName=Shutter action fixture\n'
        printf 'Exec=/usr/bin/true\n'
        printf 'Icon=application-x-executable\n'
        printf 'NoDisplay=false\n'
        printf 'Actions=%s\n' "$ids"
        for index in $(seq 1 "$count"); do
            printf '\n[Desktop Action Option%s]\n' "$index"
            printf 'Name=Option %02d\n' "$index"
            printf 'Exec=/usr/bin/touch /tmp/ryoku-launcher-qa-option-%s-%02d\n' \
                "$count" "$index"
        done
    } >"$target"
}

setup() {
    mkdir -p "$state" "$app_dir" "$(dirname "$xbel")" \
        "$launcher_config_dir" "$launcher_state_dir"

    local count target backup
    for count in $(seq 0 8); do
        target="${app_dir}/$(fixture_name "$count")"
        backup="$(desktop_backup "$count")"
        if [[ -e "$target" || -L "$target" ]]; then
            mv -- "$target" "$backup"
        fi
        write_desktop_fixture "$count"
    done

    stash_file "$xbel" "recently-used.xbel"
    stash_file "$launcher_config_dir/launcher-snippets.json" "launcher-snippets.json"
    stash_file "$launcher_config_dir/launcher-quicklinks.json" "launcher-quicklinks.json"
    stash_file "$launcher_config_dir/launcher-scripts.json" "launcher-scripts.json"
    stash_file "$launcher_state_dir/launcher-usage.json" "launcher-usage.json"
    stash_file "$launcher_config_dir/launcher.json" "launcher.json"
    : >"$recent_path"
    {
        printf '<?xml version="1.0"?>\n'
        printf '<xbel version="1.0">\n'
        printf '  <bookmark href="file:///tmp/ryoku-launcher-qa-recent.txt" modified="2026-07-24T12:00:00Z">\n'
        printf '    <title>Ryoku QA Recent</title>\n'
        printf '  </bookmark>\n'
        printf '</xbel>\n'
    } >"$xbel"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$app_dir" >/dev/null 2>&1 || true
    fi
}

teardown() {
    local count target backup
    for count in $(seq 0 8); do
        target="${app_dir}/$(fixture_name "$count")"
        backup="$(desktop_backup "$count")"
        rm -f -- "$target"
        if [[ -e "$backup" || -L "$backup" ]]; then
            mv -- "$backup" "$target"
        fi
    done

    restore_file "$xbel" "recently-used.xbel"
    restore_file "$launcher_config_dir/launcher-snippets.json" "launcher-snippets.json"
    restore_file "$launcher_config_dir/launcher-quicklinks.json" "launcher-quicklinks.json"
    restore_file "$launcher_config_dir/launcher-scripts.json" "launcher-scripts.json"
    restore_file "$launcher_state_dir/launcher-usage.json" "launcher-usage.json"
    restore_file "$launcher_config_dir/launcher.json" "launcher.json"
    rm -f -- "$recent_path"
    rm -f -- /tmp/ryoku-launcher-qa-option-*

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$app_dir" >/dev/null 2>&1 || true
    fi
    : >"$state/restored"
}

case "$mode" in
setup) setup ;;
teardown) teardown ;;
*) printf 'usage: %s setup|teardown\n' "$0" >&2; exit 2 ;;
esac
