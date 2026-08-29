#!/usr/bin/env bash
set -euo pipefail

repo=${RYOKU_PATH:-$(cd "$(dirname "$0")/.." && pwd)}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'terminal-shell-parity: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || fail "$1 is not installed"; }

if grep -RqsE '^[[:space:]]*shell[[:space:]]+/usr/bin/(fish|bash|zsh)([[:space:]]|$)' "$repo/ryoku/apps"; then
  fail "a terminal emulator pins a shell instead of following the account choice"
fi
grep -Fq 'apps/kitty/kitty.conf' "$repo/ryoku/shell/deploy.sh" ||
  fail "dev deploy does not refresh Kitty's shell policy"
bash_cfg=$repo/ryoku/apps/bash/ryoku.bash
grep -Fq '{ "type": "command", "key": "SHELL"' "$repo/ryoku/apps/fastfetch/config.jsonc" ||
  fail "Fastfetch shell readout does not follow the selected session shell"
grep -Fq 'apps/fastfetch/config.jsonc' "$repo/ryoku/shell/deploy.sh" ||
  fail "dev deploy does not refresh Fastfetch's shell readout"
fzf_line=$(grep -n 'fzf --bash' "$bash_cfg" | sed -n '1s/:.*//p')
ble_line=$(grep -n '/usr/share/blesh/ble.sh' "$bash_cfg" | sed -n '1s/:.*//p')
(( fzf_line < ble_line )) || fail "Bash must initialize fzf before ble.sh"
starship_line=$(grep -n 'starship init bash' "$bash_cfg" | sed -n '1s/:.*//p')
for rule in \
  'command_alias fg=#e2342a' \
  'command_function fg=#e2342a' \
  'command_file fg=#e2342a' \
  'syntax_varname fg=#93D4E0' \
  'syntax_quoted fg=#A3C293' \
  'syntax_error fg=#FF6B6B' \
  'auto_complete fg=#949699'; do
  grep -Fq "$rule" "$bash_cfg" || fail "Bash palette missing $rule"
done

zsh_cfg=$repo/ryoku/apps/zsh/ryoku.zsh
for rule in \
  "ZSH_HIGHLIGHT_STYLES[alias]='fg=#e2342a'" \
  "ZSH_HIGHLIGHT_STYLES[builtin]='fg=#e2342a'" \
  "ZSH_HIGHLIGHT_STYLES[function]='fg=#e2342a'" \
  "ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#CCD0CF'" \
  "ZSH_HIGHLIGHT_STYLES[redirection]='fg=#8AA9CC'" \
  "ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#e83b30'" \
  "ZSH_HIGHLIGHT_STYLES[globbing]='fg=#93D4E0'"; do
  grep -Fq "$rule" "$zsh_cfg" || fail "Zsh palette missing $rule"
done
grep -Fxq 'pkgver=0.4.0_devel3' "$repo/release/packages/blesh/PKGBUILD" ||
  fail "ble.sh 0.4 or newer is required for Starship prompt integration"
(( ble_line < starship_line )) || fail "Bash must initialize Starship after ble.sh"
need fish
need bash
need zsh

stub="$tmp/bin"
mkdir -p "$stub"
for tool in ryoku-fastfetch starship zoxide mise fzf fd eza; do
  cat >"$stub/$tool" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$RYOKU_SHELL_LOG"
case "$(basename "$0")" in
  starship|zoxide|mise|fzf) printf ':\n' ;;
esac
STUB
  chmod +x "$stub/$tool"
done

run_shell() {
  local shell=$1 home="$tmp/$1" out="$tmp/$1.out" log="$tmp/$1.log"
  mkdir -p "$home/.config/fish" "$home/.config/bash" "$home/.config/zsh" "$home/.local/bin"
  : >"$log"
  case $shell in
    fish)
      env -u EDITOR -u VISUAL HOME="$home" PATH="$stub:/usr/bin" RYOKU_SHELL_LOG="$log" fish -i -c \
        "source '$repo/ryoku/apps/fish/config.fish'; printf 'ENV=%s|%s|%s|%s\n' \"\$GOBIN\" \"\$CARGO_INSTALL_ROOT\" \"\$EDITOR\" \"\$VISUAL\"; functions ls; set -q fish_color_command; and echo EDIT=fish" >"$out" 2>&1 ||
        { cat "$out" >&2; fail "$shell startup failed"; }
      ;;
    bash)
      script -qec "env -u EDITOR -u VISUAL HOME='$home' PATH='$stub:/usr/bin' RYOKU_SHELL_LOG='$log' bash --noprofile --rcfile '$repo/ryoku/apps/bash/ryoku.bash' -i -c 'printf \"ENV=%s|%s|%s|%s\\n\" \"\$GOBIN\" \"\$CARGO_INSTALL_ROOT\" \"\$EDITOR\" \"\$VISUAL\"; alias ls'" /dev/null >"$out" 2>&1 ||
        { cat "$out" >&2; fail "$shell startup failed"; }
      ;;
    zsh)
      env -u EDITOR -u VISUAL HOME="$home" PATH="$stub:/usr/bin" RYOKU_SHELL_LOG="$log" ZDOTDIR="$home/.config/zsh" zsh -dfi -c \
        "source '$repo/ryoku/apps/zsh/ryoku.zsh'; printf 'ENV=%s|%s|%s|%s\\n' \"\$GOBIN\" \"\$CARGO_INSTALL_ROOT\" \"\$EDITOR\" \"\$VISUAL\"; alias ls; (( \$+functions[_zsh_highlight] )) && print EDIT=zsh" >"$out" 2>&1 ||
        { cat "$out" >&2; fail "$shell startup failed"; }
      ;;
  esac
  if grep -Fq 'unsupported readline function' "$out"; then
    fail "$shell startup emitted unsupported Readline warnings"
  fi
  grep -Fq "ENV=$home/.local/bin|$home/.local|nvim|nvim" "$out" || fail "$shell environment mismatch"
  grep -q "eza -lh --group-directories-first" "$out" || fail "$shell ls alias missing"
  test "$(grep -c '^ryoku-fastfetch ' "$log")" -eq 1 || fail "$shell fastfetch count"
  grep -Fq "starship init $shell" "$log" || fail "$shell starship init"
  case $shell in
    fish) grep -Fq 'EDIT=fish' "$out" || fail "fish editing layer" ;;
    bash) test -r /usr/share/blesh/ble.sh || fail "bash editing layer" ;;
    zsh) grep -Fq 'EDIT=zsh' "$out" || fail "zsh editing layer" ;;
  esac
  grep -Fq "zoxide init $shell --cmd cd" "$log" || fail "$shell zoxide init"
  grep -Fq "mise activate $shell" "$log" || fail "$shell mise init"
  grep -Fq "fzf --$shell" "$log" || fail "$shell fzf init"
}

run_shell fish
run_shell bash
run_shell zsh
printf 'terminal shell parity: fish bash zsh passed\n'
