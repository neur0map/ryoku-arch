#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

script="bin/ryoku-obsidian-notes"
[[ -x $script ]] || fail "ryoku-obsidian-notes should be executable"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

vault="$tmpdir/Ryoku Notes"
test_home="$tmpdir/user-dir"
discovered_vault="$test_home/Documents/Obsidian Vault"
mkdir -p "$tmpdir/config/obsidian" "$discovered_vault"
cat >"$tmpdir/config/obsidian/obsidian.json" <<EOF
{"vaults":{"older":{"path":"$test_home/Documents/Old Vault","ts":1,"open":false},"active":{"path":"$discovered_vault","ts":2,"open":true}}}
EOF

discovered_path=$(HOME="$test_home" XDG_CONFIG_HOME="$tmpdir/config" "$script" path --daily-dir Daily --date 2026-05-27)
[[ $discovered_path == "$discovered_vault/Daily/2026-05-27.md" ]] \
  || fail "default vault path should discover Obsidian's active vault, got $discovered_path"

daily_path=$("$script" path --vault-dir "$vault" --daily-dir Daily --date 2026-05-27)
[[ $daily_path == "$vault/Daily/2026-05-27.md" ]] \
  || fail "daily path should point inside the configured vault, got $daily_path"

saved_path=$("$script" save --vault-dir "$vault" --daily-dir Daily --date 2026-05-27 --content $'# Meeting\n- [ ] follow up' --print-path)
[[ $saved_path == "$daily_path" ]] \
  || fail "save should print the daily note path, got $saved_path"
[[ -f $daily_path ]] || fail "save should create the daily markdown note"
grep -qx '# 2026-05-27' "$daily_path" \
  || fail "daily note should start with a date heading"
grep -qx -- '- \[ \] follow up' "$daily_path" \
  || fail "daily note should preserve markdown task content"
grep -Eq '^## [0-9]{2}:[0-9]{2}$' "$daily_path" \
  || fail "saved note should be appended under a timestamp heading"

"$script" save --vault-dir "$vault" --daily-dir Daily --date 2026-05-27 --content 'second entry' --print-path >/dev/null
grep -qx 'second entry' "$daily_path" \
  || fail "subsequent saves should append to the same daily note"
(( $(grep -Ec '^## [0-9]{2}:[0-9]{2}$' "$daily_path") >= 2 )) \
  || fail "subsequent saves should append a fresh timestamp section"

widget_path=$("$script" save --vault-dir "$vault" --daily-dir Daily --date 2026-05-28 --content 'first widget body' --print-path --print-entry-id)
widget_note_path=${widget_path%%$'\n'*}
widget_entry_id=${widget_path##*$'\n'}
[[ $widget_note_path == "$vault/Daily/2026-05-28.md" ]] \
  || fail "widget save should print the note path first, got $widget_note_path"
[[ -n $widget_entry_id && $widget_entry_id != "$widget_note_path" ]] \
  || fail "widget save should print a generated entry id"
grep -q "<!-- ryoku-widget-note:id=$widget_entry_id" "$widget_note_path" \
  || fail "widget save should mark the markdown section with an editable entry id"

"$script" save --vault-dir "$vault" --daily-dir Daily --date 2026-05-28 --entry-id "$widget_entry_id" --content 'edited widget body' --print-path --print-entry-id >/dev/null
grep -qx 'edited widget body' "$widget_note_path" \
  || fail "saving a selected widget note should update its markdown body"
if grep -qx 'first widget body' "$widget_note_path"; then
  fail "saving a selected widget note should replace the old markdown body"
fi
[[ $(grep -c "<!-- ryoku-widget-note:id=$widget_entry_id" "$widget_note_path") == 1 ]] \
  || fail "saving a selected widget note should keep one editable widget marker"
[[ $(grep -Ec '^## [0-9]{2}:[0-9]{2}$' "$widget_note_path") == 1 ]] \
  || fail "saving a selected widget note should not append a new timestamp section"

named_vault_path=$("$script" save --vault-dir "$vault" --vault-name "Ryoku Notes" --daily-dir Daily --date 2026-05-27 --content 'named vault entry' --print-path)
[[ $named_vault_path == "$daily_path" ]] \
  || fail "save should tolerate a configured vault name, got $named_vault_path"
grep -qx 'named vault entry' "$daily_path" \
  || fail "save with a configured vault name should still append markdown content"

inbox_path=$("$script" save --vault-dir "$vault" --inbox-file Inbox.md --content 'quick inbox' --print-path)
[[ $inbox_path == "$vault/Inbox.md" ]] \
  || fail "inbox save should print the configured inbox path, got $inbox_path"
grep -qx '# Inbox' "$inbox_path" \
  || fail "inbox note should start with an Inbox heading"
grep -qx 'quick inbox' "$inbox_path" \
  || fail "inbox note should contain quick note content"

uri=$("$script" open --vault-dir "$vault" --vault-name "Ryoku Notes" --daily-dir Daily --date 2026-05-27 --print-uri)
[[ $uri == 'obsidian://open?vault=Ryoku%20Notes&file=Daily%2F2026-05-27.md' ]] \
  || fail "open should build an encoded vault/file Obsidian URI, got $uri"

path_uri=$("$script" open --vault-dir "$vault" --daily-dir Daily --date 2026-05-27 --print-uri)
case "$path_uri" in
  obsidian://open?path=*Ryoku%20Notes%2FDaily%2F2026-05-27.md) ;;
  *) fail "open without vault name should build an encoded path Obsidian URI, got $path_uri" ;;
esac

if "$script" path --vault-dir "$vault" --daily-dir ../bad --date 2026-05-27 >/dev/null 2>"$tmpdir/error.log"; then
  fail "path traversal in daily dir should fail"
fi
grep -q "unsafe relative path" "$tmpdir/error.log" \
  || fail "unsafe daily dir should report a validation error"

if "$script" path --vault-dir "$vault" --inbox-file ../bad.md >/dev/null 2>"$tmpdir/error.log"; then
  fail "path traversal in inbox file should fail"
fi
grep -q "unsafe relative path" "$tmpdir/error.log" \
  || fail "unsafe inbox file should report a validation error"

if "$script" path --vault-dir "$vault" --daily-dir Daily --date 2026-02-31 >/dev/null 2>"$tmpdir/error.log"; then
  fail "invalid dates should fail"
fi
grep -q "invalid --date" "$tmpdir/error.log" \
  || fail "invalid dates should report a validation error"

echo "PASS: ryoku obsidian notes"
