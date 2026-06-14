# Build the Ryoku Quickshell shell: the native Qt6 QML plugins (Ryoku, Ryoku.*)
# plus the runtime QML/asset tree that shell.qml loads. quickshell itself comes
# from nixpkgs; this derivation produces the plugins (under lib/qt6/qml) and the
# config tree (etc/xdg/quickshell/ryoku-shell) that `qs -p <dir>` runs.
#
# CMake variable map (see shell/CMakeLists.txt):
#   INSTALL_QMLDIR   -> the QML import dir the session adds to QML_IMPORT_PATH
#   INSTALL_QSCONFDIR-> the Quickshell config dir passed to `qs -p`
#   INSTALL_LIBDIR   -> auxiliary native libs
# VERSION is passed so CMake skips its `git describe` fallback (no git here).
{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  qt6,
  libqalculate,
  pipewire,
  aubio,
  libcava,
  fftw,
}:
let
  # nixpkgs libcava ships lib/pkgconfig/cava.pc with headers under include/cava,
  # but the shell's CMake asks pkg-config for `libcava` and the plugin includes
  # <cava/cavacore.h>. Add a libcava.pc alias that also exposes -I${includedir}
  # so both the module name and the <cava/...> include resolve. The dependency is
  # adapted in the Nix layer; shell/ source stays pristine.
  libcava-compat = libcava.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      sed -e 's|^Cflags: |Cflags: -I''${includedir} |' \
        "$out/lib/pkgconfig/cava.pc" > "$out/lib/pkgconfig/libcava.pc"
    '';
  });
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ryoku-shell";
  version = "0.1.0";

  src = lib.cleanSource ../../shell;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.qtshadertools
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtshadertools
    libqalculate
    pipewire
    aubio
    libcava-compat
    fftw
  ];

  cmakeFlags = [
    (lib.cmakeFeature "VERSION" finalAttrs.version)
    (lib.cmakeFeature "GIT_REVISION" "nixos")
    (lib.cmakeFeature "DISTRIBUTOR" "ryoku")
    (lib.cmakeFeature "INSTALL_LIBDIR" "lib/ryoku-shell")
    (lib.cmakeFeature "INSTALL_QMLDIR" "lib/qt6/qml")
    (lib.cmakeFeature "INSTALL_QSCONFDIR" "etc/xdg/quickshell/ryoku-shell")
  ];

  meta = {
    description = "Ryoku Hyprland desktop shell (Quickshell QML + native Qt6 plugins)";
    # Aggregate tree: settingsgui is MIT, dashboard is AGPL-3.0-only; the rest is Ryoku.
    license = with lib.licenses; [
      agpl3Only
      mit
    ];
    platforms = lib.platforms.linux;
  };
})
