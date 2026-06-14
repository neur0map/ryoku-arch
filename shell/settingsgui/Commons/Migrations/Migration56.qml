import QtQuick
import Quickshell
import qs.settingsgui.Commons

QtObject {
  id: root

  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v56 (Color Scheme Migration)");

    const scriptPath = Quickshell.shellDir + "/settingsgui" + "/Scripts/python/src/theming/migrate-colorschemes.py";
    const configDir = Settings.configDir;

    logger.i("Settings", `Running color scheme migration script: ${scriptPath} with configDir: ${configDir}`);

    Quickshell.execDetached(["python3", scriptPath, configDir]);

    return true;
  }
}
