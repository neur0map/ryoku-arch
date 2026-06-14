# qylock: the Ryoku lockscreen (vendored faithful upstream under vendor/qylock).
# It reuses SDDM themes as Quickshell WlSessionLock surfaces and authenticates
# through Quickshell.Services.Pam against /etc/pam.d/login. The shell's LockBridge
# execs $HOME/.local/share/quickshell-lockscreen/lock.sh; the session module
# symlinks that path at startup to this store tree. Themes ship under themes_link/
# so lock.sh resolves QS_THEME_PATH=$DIR/themes_link/<theme> without touching
# $HOME/.local/share/themes.
{
  runCommand,
  qylockSrc ? ../../vendor/qylock,
}:
runCommand "ryoku-qylock" { } ''
  dest="$out/share/ryoku/qylock"
  mkdir -p "$dest/themes_link"
  cp -r ${qylockSrc}/quickshell-lockscreen/. "$dest/"
  cp -r ${qylockSrc}/themes/. "$dest/themes_link/"
  chmod -R u+w "$dest"
  chmod +x "$dest/lock.sh"
''
