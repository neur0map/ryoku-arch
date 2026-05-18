#!/bin/bash

if [[ -z $1 ]]; then
  echo "Usage: $0 <target_locale> [model]"
  exit 1
fi

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
SHELL_CONFIG_DIR="$(ryoku_shell_config_dir)"
SHELL_CONFIG_FILE="$(ryoku_shell_config_file)"
TRANSLATIONS_DIR="${SCRIPT_DIR}/../../translations"
TRANSLATIONS_TARGET_DIR="${SHELL_CONFIG_DIR}/translations"
SOURCE_LOCALE="en_US"
NOTIFICATION_APP_NAME="Shell"
TARGET_LOCALE="$1"
MODEL="${2:-${GEMINI_MODEL:-gemini-2.5-flash}}"
TARGET_FILE="${TRANSLATIONS_TARGET_DIR}/${TARGET_LOCALE}.json"

notify_error() {
  notify-send -u critical "Translation failed" "$1" -a "$NOTIFICATION_APP_NAME"
  echo "ERROR: $1" >&2
  exit 1
}

# Update the source keys for translation
"${TRANSLATIONS_DIR}/tools/manage-translations.sh" update -l "$SOURCE_LOCALE" --yes
mkdir -p "$TRANSLATIONS_TARGET_DIR"

# Get API key
API_KEY=$(secret-tool lookup 'application' 'illogical-impulse' 2>/dev/null | jq -r '.apiKeys.gemini // empty')
if [[ -z $API_KEY || $API_KEY == "null" ]]; then
  notify_error "Gemini API key not set. Type /key on the AI sidebar to configure."
fi

# Notify start
notify-send "Translation started" "Translating to $TARGET_LOCALE with $MODEL. Takes ~2 minutes, you'll be notified when done." -a "$NOTIFICATION_APP_NAME"

# Build payload via jq. --rawfile avoids MAX_ARG_STRLEN.
instruction='You are to translate the user interface of a **desktop shell**. Given a JSON object of key-value pairs, return a JSON with the same structure, with keys unchanged and values translated to '"$TARGET_LOCALE"'. Be as **concise** as possible to save screen space, and make sure terminology is relevant (e.g. "discharging" refers to the battery status). Preserve placeholders like %1, %2, {0}, <name> verbatim. Preserve newline characters (\n) and HTML/markup tags exactly as in the source.'

# Five-minute timeout: long enough for the locale payload, short enough to detect API hangs.
response=$(jq -n \
  --arg prompt_text "$instruction" \
  --rawfile content "${TRANSLATIONS_DIR}/en_US.json" \
  --arg temperature "0" \
  --arg model "$MODEL" \
  '{
    contents: [{
      parts: [
        {text: ($prompt_text + "\n```\n" + $content + "\n```\n")}
      ]
    }],
    generationConfig: {
      temperature: ($temperature | tonumber),
      "responseMimeType": "application/json"
    }
  }' | curl --max-time 300 --fail-with-body --silent --show-error \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
  -H "x-goog-api-key: $API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d @- 2>&1)
curl_status=$?

if (( curl_status != 0 )); then
  api_err="$(jq -r '.error.message // empty' <<< "$response" 2>/dev/null)"
  notify_error "Gemini API call failed (curl ${curl_status}). ${api_err:-Network or auth error.}"
fi

translated="$(jq -r '.candidates[0].content.parts[0].text // empty' <<< "$response" 2>/dev/null)"
if [[ -z $translated ]]; then
  api_err="$(jq -r '.error.message // empty' <<< "$response" 2>/dev/null)"
  notify_error "Empty Gemini response. ${api_err:-(model may have refused; check API quota/safety filters)}"
fi

if ! jq -e 'type == "object"' <<< "$translated" >/dev/null 2>&1; then
  notify_error "Gemini returned non-JSON output. Translation discarded; your existing $TARGET_LOCALE.json is untouched."
fi

tmp_file="${TARGET_FILE}.tmp.$$"
printf '%s\n' "$translated" > "$tmp_file"
if ! jq -e '.' "$tmp_file" >/dev/null 2>&1; then
  rm -f "$tmp_file"
  notify_error "Final JSON validation failed. Translation discarded."
fi
mv "$tmp_file" "$TARGET_FILE"

(
  flock -w 5 200 || { echo "config lock timeout" >&2; exit 1; }
  jq --arg locale "$TARGET_LOCALE" '.language.ui = $locale' "$SHELL_CONFIG_FILE" > "${SHELL_CONFIG_FILE}.tmp" \
    && mv "${SHELL_CONFIG_FILE}.tmp" "$SHELL_CONFIG_FILE"
) 200>"${SHELL_CONFIG_FILE}.lock"
notify-send "Translation complete" "Saved to ${TARGET_FILE}. Edit there to refine." -a "$NOTIFICATION_APP_NAME"
