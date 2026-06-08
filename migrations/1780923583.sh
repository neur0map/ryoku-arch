echo "Wire fd/eza/fzf-preview/zoxide-cd/lazygit and shortcuts into fish"

# New installs ship these in config.fish directly. Existing config.fish files
# only had the minimal eza alias and no fd/lazygit/cd wiring, so append a
# guarded block on top of whatever the user already has. Idempotent via the
# marker, and additive so any user customizations survive.
fish_config="$HOME/.config/fish/config.fish"

[[ -f $fish_config ]] || exit 0
grep -q 'ryoku-cli-tool-integrations' "$fish_config" && exit 0

cat >>"$fish_config" <<'EOF'

# >>> ryoku-cli-tool-integrations >>>
# Ryoku CLI tool wiring (fd, eza, fzf preview, zoxide-backed cd, lazygit, and
# common shortcuts). Layered on top of the existing config so it does not
# clobber anything above.
if status is-interactive
  if command -v fd >/dev/null 2>&1
    set -gx FZF_DEFAULT_COMMAND 'fd --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
  end

  if command -v eza >/dev/null 2>&1
    alias ls 'eza -lh --group-directories-first --icons=auto'
    alias lsa 'ls -a'
    alias lt 'eza --tree --level=2 --long --icons --git'
    alias lta 'lt -a'
  end

  if command -v fzf >/dev/null 2>&1
    function ff --description 'fzf file picker with preview'
      if test "$TERM" = xterm-kitty
        fzf --preview 'case $(file --mime-type -b {}) in image/*) kitty icat --clear --transfer-mode=memory --stdin=no --place=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0 {} ;; *) bat --style=numbers --color=always {} ;; esac'
      else
        fzf --preview 'bat --style=numbers --color=always {}'
      end
    end
    function eff --description 'edit a file chosen via fzf'
      set -l file (ff)
      test -n "$file"; and $EDITOR "$file"
    end
    function sff --description 'scp a recent file chosen via fzf'
      if test (count $argv) -eq 0
        echo "Usage: sff <destination> (e.g. sff host:/tmp/)"
        return 1
      end
      set -l file (find . -type f -printf '%T@\t%p\n' | sort -rn | cut -f2- | ff)
      test -n "$file"; and scp "$file" $argv[1]
    end
  end

  if command -v zoxide >/dev/null 2>&1
    function cd --description 'cd, falling back to a zoxide jump'
      if test (count $argv) -eq 0
        builtin cd ~
      else if test -d "$argv[1]"
        builtin cd $argv
      else if z $argv
        printf '\U000F17A9 '
        builtin pwd
      else
        echo "Error: Directory not found"
        return 1
      end
    end
  end

  if command -v lazygit >/dev/null 2>&1
    alias lg lazygit
  end

  alias .. 'cd ..'
  alias ... 'cd ../..'
  alias .... 'cd ../../..'
  alias g git
  alias gcm 'git commit -m'
  alias gcam 'git commit -a -m'
  alias gcad 'git commit -a --amend'
  if command -v docker >/dev/null 2>&1
    alias d docker
  end
  if command -v tmux >/dev/null 2>&1
    alias t 'tmux attach; or tmux new -s Work'
  end
  function e --description 'nvim, current directory if no args'
    if test (count $argv) -eq 0
      command nvim .
    else
      command nvim $argv
    end
  end
  function open --description 'xdg-open in the background'
    xdg-open $argv >/dev/null 2>&1 &
  end
end
# <<< ryoku-cli-tool-integrations <<<
EOF

echo "Added Ryoku CLI tool integrations to ~/.config/fish/config.fish"
