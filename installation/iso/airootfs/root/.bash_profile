# shellcheck shell=bash
# Root's login shell on the live ISO is bash. Route through .zlogin so the
# install-on-tty1 logic lives in one place and behaves the same under zsh.
# shellcheck source=/dev/null
[[ -f /root/.zlogin ]] && source /root/.zlogin
