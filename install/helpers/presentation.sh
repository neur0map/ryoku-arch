# --- UI helpers: prefer ryoku-tui, fall back to plain bash ----------------
# ryoku-tui is a drop-in for the old `gum` subcommands (style/confirm/spin/
# choose), but it is built LATER during a fresh install, so it may not be on
# PATH yet. Every UI call must therefore guard for it and never stall.

# _ui_read PROMPT VARNAME -> read one line into VARNAME, preferring an
# interactive read from /dev/tty (the install script itself owns stdin), but
# falling back to stdin when /dev/tty cannot be opened. Never errors out: on
# any read failure the variable is left empty so callers apply their default.
_ui_read() {
  local _prompt="$1"
  local -n _out_ref="$2"
  _out_ref=""
  if { exec 9</dev/tty; } 2>/dev/null; then
    read -r -p "$_prompt" _out_ref <&9 || _out_ref=""
    exec 9<&-
  else
    read -r -p "$_prompt" _out_ref || _out_ref=""
  fi
}

# ui_style [flags...] TEXT  -> styled box if ryoku-tui present, else plain text.
# Fallback prints only the final positional argument (the human text); all
# call sites pass the text as the last argument.
ui_style() {
  if command -v ryoku-tui &>/dev/null; then
    ryoku-tui style "$@"
  else
    local text=""
    if (($#)); then
      text="${*: -1}"
    fi
    printf '%s\n' "$text"
  fi
}

# ui_confirm [flags...] PROMPT -> ryoku-tui confirm, else plain read (default No).
# Fallback uses the last positional argument as the prompt and preserves the
# "non-zero unless the user affirms" exit-code contract.
ui_confirm() {
  if command -v ryoku-tui &>/dev/null; then
    ryoku-tui confirm "$@"
  else
    local prompt=""
    if (($#)); then
      prompt="${*: -1}"
    fi
    local answer=""
    _ui_read "$prompt [y/N] " answer
    [[ $answer == [yY]* ]]
  fi
}

# ui_spin --title TITLE -- CMD... -> spinner if ryoku-tui present, else run CMD
# directly (no spinner). Either way the command's exit code is preserved.
ui_spin() {
  if command -v ryoku-tui &>/dev/null; then
    ryoku-tui spin "$@"
  else
    # Strip everything up to and including the `--` separator, then run the
    # remaining command. If there is no separator, run all args as a command.
    while (($#)); do
      if [[ $1 == "--" ]]; then
        shift
        break
      fi
      shift
    done
    "$@"
  fi
}

# ui_choose [flags...] ITEM... -> ryoku-tui choose, else plain numbered select.
# Fallback reads the choice from /dev/tty and echoes the selected item to
# stdout, matching gum's output contract. Flags (starting with -) are ignored
# in the fallback; remaining positional args are the selectable items.
ui_choose() {
  if command -v ryoku-tui &>/dev/null; then
    ryoku-tui choose "$@"
  else
    local items=()
    while (($#)); do
      case "$1" in
      --*=* | -*)
        # Skip a flag; if it is a known value-taking flag, also skip its value.
        case "$1" in
        --header | --height | --padding | --limit)
          shift
          ;;
        esac
        ;;
      *)
        items+=("$1")
        ;;
      esac
      shift
    done

    local i
    for i in "${!items[@]}"; do
      printf '%2d) %s\n' "$((i + 1))" "${items[i]}" >&2
    done

    local reply=""
    _ui_read "Choose [1-${#items[@]}]: " reply
    if [[ $reply =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#items[@]})); then
      printf '%s\n' "${items[reply - 1]}"
    fi
  fi
}

# Get terminal size from /dev/tty (works in all scenarios: direct, sourced, or piped)
if [[ -e /dev/tty ]]; then
  TERM_SIZE=$(stty size 2>/dev/null </dev/tty)

  if [[ -n $TERM_SIZE ]]; then
    TERM_HEIGHT=$(echo "$TERM_SIZE" | cut -d' ' -f1)
    TERM_WIDTH=$(echo "$TERM_SIZE" | cut -d' ' -f2)
    export TERM_HEIGHT
    export TERM_WIDTH
  else
    # Fallback to reasonable defaults if stty fails
    export TERM_WIDTH=80
    export TERM_HEIGHT=24
  fi
else
  # No terminal available (e.g., non-interactive environment)
  export TERM_WIDTH=80
  export TERM_HEIGHT=24
fi

export LOGO_PATH="$RYOKU_PATH/assets/brand/logo.txt"
LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH" 2>/dev/null || echo 0)
LOGO_HEIGHT=$(wc -l <"$LOGO_PATH" 2>/dev/null || echo 0)
export LOGO_WIDTH
export LOGO_HEIGHT

export PADDING_LEFT=$(((TERM_WIDTH - LOGO_WIDTH) / 2))
if (( PADDING_LEFT < 0 )); then
  PADDING_LEFT=0
fi
PADDING_LEFT_SPACES=$(printf "%*s" "$PADDING_LEFT" "")
export PADDING_LEFT
export PADDING_LEFT_SPACES

# Shared padding string for boxed UI output (left-aligned under the logo).
export PADDING="0 0 0 $PADDING_LEFT"

clear_logo() {
  printf "\033[H\033[2J" # Clear screen and move cursor to top-left
  ui_style --foreground 2 --padding "1 0 0 $PADDING_LEFT" "$(<"$LOGO_PATH")"
}
