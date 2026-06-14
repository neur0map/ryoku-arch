# A clean default wallpaper for the Ryoku session, generated at build time so no
# binary blob (and no third-party image licensing) lives in the repo. It gives
# the desktop a branded background out of the box; users replace it via the
# wallpaper selector, and the full rice wallpaper collection is a later content
# decision (git-lfs or a fetched set).
{
  runCommand,
  imagemagick,
}:
runCommand "ryoku-wallpapers" { nativeBuildInputs = [ imagemagick ]; } ''
  mkdir -p "$out/share/ryoku/wallpapers"
  magick -size 3840x2160 radial-gradient:'#26283b'-'#0d0e16' \
    "$out/share/ryoku/wallpapers/ryoku-default.png"
''
