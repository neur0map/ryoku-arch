import QtQuick

QtObject {
  id: root

  function migrate(adapter, logger, rawJson) {
    logger.i("Migration42", "Migrating randomEnabled to automationEnabled");

    const wallpaper = rawJson?.wallpaper;
    if (!wallpaper) {
      logger.d("Migration42", "No wallpaper section found, skipping migration");
      return true;
    }

    // Check if already migrated (has automationEnabled)
    if (wallpaper.automationEnabled !== undefined) {
      logger.d("Migration42", "Already has automationEnabled, skipping migration");
      return true;
    }

    // Migrate randomEnabled to automationEnabled
    const oldValue = wallpaper.randomEnabled ?? false;
    adapter.wallpaper.automationEnabled = oldValue;
    logger.i("Migration42", "Migrated randomEnabled=" + oldValue + " to automationEnabled=" + oldValue);

    return true;
  }
}
