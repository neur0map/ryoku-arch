# v2 S2: launch the Ryoku Quickshell shell in the Hyprland session. quickshell
# (qs) loads the native Ryoku.* plugins from ryoku-shell's qml dir and runs the
# installed config tree. The shell is started from a minimal system Hyprland
# config via exec-once, so it inherits the compositor environment it needs
# (HYPRLAND_INSTANCE_SIGNATURE, WAYLAND_DISPLAY). greetd launches the session
# script ryoku-hypr-session (see modules/desktop). The full rice (keybinds,
# theming, the ryoku-* runtime) lands in later v2 slices.
{ pkgs, lib, ... }:
let
  shell = pkgs.ryoku-shell;
  qs = pkgs.quickshell;
  shellConfig = "${shell}/etc/xdg/quickshell/ryoku-shell";
  # ryoku-shell installs its native plugins under lib/qt6/qml; the extra Qt QML
  # modules the shell imports beyond quickshell's base Qt (Qt5Compat.GraphicalEffects
  # and QtMultimedia) live under each package's lib/qt-6/qml.
  qmlPath = lib.concatStringsSep ":" (
    [ "${shell}/lib/qt6/qml" ]
    ++ map (p: "${p}/lib/qt-6/qml") [ pkgs.qt6.qt5compat pkgs.qt6.qtmultimedia pkgs.kdePackages.kirigami.unwrapped ]
  );

  ryoku-hypr-session = pkgs.writeShellScriptBin "ryoku-hypr-session" ''
    exec ${pkgs.hyprland}/bin/Hyprland --config /etc/ryoku/hyprland.conf
  '';
in
{
  environment.systemPackages = [
    qs
    shell
    ryoku-hypr-session
  ];

  environment.etc."ryoku/hyprland.conf".text = ''
    # Plugins + the extra Qt QML modules the shell imports.
    env = QML_IMPORT_PATH,${qmlPath}
    env = QML2_IMPORT_PATH,${qmlPath}

    exec-once = ${qs}/bin/qs -p ${shellConfig}

    # A terminal keybind keeps the session usable for manual testing.
    bind = SUPER, Return, exec, ${pkgs.foot}/bin/foot
  '';
}
