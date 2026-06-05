import QtQuick
import Quickshell
import qs.settingsgui.Commons

QtObject {
  id: root

  function migrate(adapter, logger, rawJson) {
    logger.i("Migration46", "Removing legacy PAM configuration file");

    const configDir = Settings.configDir;
    const pamConfigDir = configDir + "pam";
    const script = `rm -rf '${pamConfigDir}'`;
    Quickshell.execDetached(["sh", "-c", script]);

    logger.d("Migration46", "Cleaned up legacy PAM config");

    return true;
  }
}
