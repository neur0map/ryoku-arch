import QtQuick

QtObject {
  id: root

  function migrate(adapter, logger, rawJson) {
    logger.i("Migration43", "Migrating recursiveSearch to viewMode");

    const wallpaper = rawJson?.wallpaper;
    if (!wallpaper) {
      logger.d("Migration43", "No wallpaper section found, skipping migration");
      return true;
    }

    // Check if already migrated (has viewMode)
    if (wallpaper.viewMode !== undefined) {
      logger.d("Migration43", "Already has viewMode, skipping migration");
      return true;
    }

    // Migrate recursiveSearch to viewMode
    const oldValue = wallpaper.recursiveSearch ?? false;
    const newValue = oldValue ? "recursive" : "single";
    adapter.wallpaper.viewMode = newValue;
    logger.i("Migration43", "Migrated recursiveSearch=" + oldValue + " to viewMode=" + newValue);

    return true;
  }
}
