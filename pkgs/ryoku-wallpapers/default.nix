# Clean default wallpapers for the Ryoku session, generated at build time so no
# binary blob (and no third-party image licensing) lives in the repo. They give
# the desktop a branded background out of the box and a few hues to switch
# between (each yields a distinct Material You accent via the wallpaper-to-scheme
# extractor). Users replace them via the wallpaper selector; the full rice
# wallpaper collection is a later content decision (git-lfs or a fetched set).
{
  runCommand,
  imagemagick,
}:
runCommand "ryoku-wallpapers" { nativeBuildInputs = [ imagemagick ]; } ''
  d="$out/share/ryoku/wallpapers"
  mkdir -p "$d"
  magick -size 3840x2160 radial-gradient:'#26283b'-'#0d0e16' "$d/ryoku-default.png"
  magick -size 3840x2160 radial-gradient:'#3b2228'-'#160a0d' "$d/ryoku-ember.png"
  magick -size 3840x2160 radial-gradient:'#22341f'-'#0a140c' "$d/ryoku-forest.png"
  magick -size 3840x2160 radial-gradient:'#33264a'-'#120d1c' "$d/ryoku-amethyst.png"
''
