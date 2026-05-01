import QtQuick

QtObject {
  id: root

  // Migrate from version < 27 to version 27
  // Converts settingsPanelAttachToBar boolean to settingsPanelMode string
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v27");

    // Check rawJson for old property (adapter doesn't expose removed properties)
    if (rawJson?.ui?.settingsPanelAttachToBar !== undefined) {
      if (rawJson.ui.settingsPanelAttachToBar === true) {
        adapter.ui.settingsPanelMode = "attached";
      } else {
        adapter.ui.settingsPanelMode = "centered";
      }
      logger.i("Settings", "Migrated settingsPanelAttachToBar to settingsPanelMode: " + adapter.ui.settingsPanelMode);
    }

    return true;
  }
}
