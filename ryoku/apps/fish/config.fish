# Put user-installed binaries on PATH for every shell (not just interactive),
# so tools dropped in ~/.local/bin (e.g. claude, oh-my-posh) are runnable and
# the ryoku-fastfetch wrapper below is found. fish_add_path is idempotent.
if test -d $HOME/.local/bin
  fish_add_path $HOME/.local/bin
end

if status is-interactive
  # No greeting: keep the login terminal clean.
  set -g fish_greeting

  set -gx EDITOR nvim
  set -gx VISUAL nvim

  # Readable fish syntax colors. fish applies a palette-tied default theme before
  # config.fish (here with a malformed flag that left typed input the same color
  # as the background). Pin a fixed, legible scheme unconditionally so it always
  # wins and stays readable under any wallust palette.
  set -g fish_color_normal         F1F3E4
  set -g fish_color_command        F25623
  set -g fish_color_keyword        F56E0F
  set -g fish_color_param          F1F3E4
  set -g fish_color_option         CCD0CF
  set -g fish_color_quote          A3C293
  set -g fish_color_redirection    8AA9CC
  set -g fish_color_end            F56E0F
  set -g fish_color_error          FF6B6B
  set -g fish_color_comment        949699
  set -g fish_color_operator       93D4E0
  set -g fish_color_escape         93D4E0
  set -g fish_color_autosuggestion 949699

  # Branded system readout when a terminal opens.
  if command -v ryoku-fastfetch >/dev/null 2>&1
    ryoku-fastfetch
  end

  # Prompt.
  if command -v starship >/dev/null 2>&1
    starship init fish | source
  end

  # Directory jumper: hook cd into zoxide so plain `cd` learns and jumps to
  # frecent directories (use `cdi` for an interactive pick).
  if command -v zoxide >/dev/null 2>&1
    zoxide init fish --cmd cd | source
  end

  # Let fzf walk the tree with fd when present.
  if command -v fd >/dev/null 2>&1
    set -gx FZF_DEFAULT_COMMAND 'fd --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
  end

  # fzf key bindings (Ctrl-R history, Ctrl-T files, Alt-C cd).
  if command -v fzf >/dev/null 2>&1
    fzf --fish | source
  end

  # eza listings.
  if command -v eza >/dev/null 2>&1
    alias ls 'eza -lh --group-directories-first --icons=auto'
    alias lsa 'ls -a'
    alias lt 'eza --tree --level=2 --long --icons --git'
    alias lta 'lt -a'
  end
end
