echo "Refresh the gd worktree-remove confirmation (no more gum)"

# The function lives in $RYOKU_PATH/default/bash/fns/worktrees and is sourced
# by the user's bash on shell start. The git pull that ran in the same update
# already updated the file in place, so existing shells keep the old gd() until
# the user opens a new shell.
if [[ -t 1 ]]; then
  echo "  (open a new terminal to refresh the gd() function)"
fi
