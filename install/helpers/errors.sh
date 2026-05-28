# Track if we're already handling an error to prevent double-trapping
ERROR_HANDLING=false

# Defensive UI shims. presentation.sh (sourced first) normally defines these,
# but the error handler must never reference an unset function, so re-define
# any that are missing. They prefer ryoku-tui and fall back to plain bash,
# because ryoku-tui is built later in a fresh install and may be absent.
if ! declare -F _ui_read >/dev/null 2>&1; then
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
fi

if ! declare -F ui_style >/dev/null 2>&1; then
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
fi

if ! declare -F ui_choose >/dev/null 2>&1; then
  ui_choose() {
    if command -v ryoku-tui &>/dev/null; then
      ryoku-tui choose "$@"
    else
      local items=()
      while (($#)); do
        case "$1" in
        --*=* | -*)
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
fi

# Cursor is usually hidden while we install
show_cursor() {
  printf "\033[?25h"
}

# Display truncated log lines from the install log
show_log_tail() {
  if [[ -f $RYOKU_INSTALL_LOG_FILE ]]; then
    local log_lines=$((TERM_HEIGHT - LOGO_HEIGHT - 35))
    local max_line_width=$((LOGO_WIDTH - 4))

    tail -n $log_lines "$RYOKU_INSTALL_LOG_FILE" | while IFS= read -r line; do
      if ((${#line} > max_line_width)); then
        local truncated_line="${line:0:$max_line_width}..."
      else
        local truncated_line="$line"
      fi

      ui_style "$truncated_line"
    done

    echo
  fi
}

# Display the failed command or script name
show_failed_script_or_command() {
  if [[ -n ${CURRENT_SCRIPT:-} ]]; then
    ui_style "Failed script: $CURRENT_SCRIPT"
  else
    # Truncate long command lines to fit the display
    local cmd="$BASH_COMMAND"
    local max_cmd_width=$((LOGO_WIDTH - 4))

    if ((${#cmd} > max_cmd_width)); then
      cmd="${cmd:0:$max_cmd_width}..."
    fi

    ui_style "$cmd"
  fi
}

# Save original stdout and stderr for trap to use
save_original_outputs() {
  exec 3>&1 4>&2
}

# Restore stdout and stderr to original (saved in FD 3 and 4)
# This ensures output goes to screen, not log file
restore_outputs() {
  if [[ -e /proc/self/fd/3 ]] && [[ -e /proc/self/fd/4 ]]; then
    exec 1>&3 2>&4
  fi
}

# Error handler
catch_errors() {
  # Prevent recursive error handling
  if [[ $ERROR_HANDLING == "true" ]]; then
    return
  else
    ERROR_HANDLING=true
  fi

  # Store exit code immediately before it gets overwritten
  local exit_code=$?

  stop_log_output
  restore_outputs

  clear_logo
  show_cursor

  ui_style --foreground 1 --padding "1 0 1 $PADDING_LEFT" "Ryoku installation stopped!"
  show_log_tail

  ui_style "This command halted with exit code $exit_code:"
  show_failed_script_or_command

  ui_style "Review the log, then file an issue at https://github.com/neur0map/ryoku-arch/issues if you need help."

  # Offer options menu
  while true; do
    options=()

    # If online install, show retry first
    if [[ -n ${RYOKU_ONLINE_INSTALL:-} ]]; then
      options+=("Retry installation")
    fi

    # Add upload option if internet is available
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
      options+=("Upload log for support")
    fi

    # Add remaining options
    options+=("View full log")
    options+=("Exit")

    choice=$(ui_choose "${options[@]}" --header "What would you like to do?" --height 6 --padding "1 $PADDING_LEFT")

    case "$choice" in
    "Retry installation")
      bash ~/.local/share/ryoku/install.sh
      break
      ;;
    "View full log")
      if command -v less &>/dev/null; then
        less "$RYOKU_INSTALL_LOG_FILE"
      else
        tail "$RYOKU_INSTALL_LOG_FILE"
      fi
      ;;
    "Upload log for support")
      ryoku-upload-log
      ;;
    "Exit" | "")
      exit 1
      ;;
    esac
  done
}

# Exit handler - ensures cleanup happens on any exit
exit_handler() {
  local exit_code=$?

  # Only run if we're exiting with an error and haven't already handled it
  if (( exit_code != 0 )) && [[ $ERROR_HANDLING != "true" ]]; then
    catch_errors
  else
    stop_log_output
    show_cursor
  fi
}

# Set up traps
trap catch_errors ERR INT TERM
trap exit_handler EXIT

# Save original outputs in case we trap
save_original_outputs
