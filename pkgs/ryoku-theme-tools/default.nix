# The shell's wallpaper-derived Material You theming, ported from the Arch CLI.
# The Quickshell Colours service reads ~/.local/state/ryoku-shell/scheme.json,
# which the bundled `ryoku` bridge generates from the current wallpaper by
# calling ryoku-wallpaper-to-scheme (extracts accents via Pillow) which in turn
# calls ryoku-theme-to-scheme (flat palette -> full M3 roles, pure stdlib). No
# matugen needed. Wrapped to a Python that carries Pillow.
{
  runCommand,
  python3,
}:
let
  py = python3.withPackages (ps: [ ps.pillow ]);
in
runCommand "ryoku-theme-tools" { } ''
  mkdir -p "$out/bin"
  install -Dm755 ${./ryoku-wallpaper-to-scheme} "$out/bin/ryoku-wallpaper-to-scheme"
  install -Dm755 ${./ryoku-theme-to-scheme} "$out/bin/ryoku-theme-to-scheme"
  for s in "$out"/bin/*; do
    substituteInPlace "$s" --replace-fail "/usr/bin/env python3" "${py}/bin/python3"
  done
''
