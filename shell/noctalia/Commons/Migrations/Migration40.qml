import QtQuick

QtObject {
  id: root

  // List of all template IDs that existed as booleans in the old format
  readonly property var templateIds: ["gtk", "qt", "kcolorscheme", "alacritty", "kitty", "ghostty", "foot", "wezterm", "fuzzel", "discord", "pywalfox", "vicinae", "walker", "code", "spicetify", "telegram", "cava", "yazi", "emacs", "niri", "hyprland", "mango", "zed", "helix", "zenBrowser"]

  function migrate(adapter, logger, rawJson) {
    logger.i("Migration39", "Migrating templates from boolean format to activeTemplates array");

    const oldTemplates = rawJson?.templates;
    if (!oldTemplates) {
      logger.d("Migration39", "No templates section found, skipping migration");
      return true;
    }

    if (Array.isArray(oldTemplates.activeTemplates)) {
      logger.d("Migration39", "Already has activeTemplates array, skipping migration");
      return true;
    }

    const activeTemplates = [];
    for (const templateId of templateIds) {
      if (oldTemplates[templateId] === true) {
        activeTemplates.push({
                               "id": templateId,
                               "enabled": true
                             });
        logger.d("Migration40", "Migrated enabled template: " + templateId);
      }
    }

    adapter.templates.activeTemplates = activeTemplates;
    logger.i("Migration40", "Migrated " + activeTemplates.length + " templates to new array format");

    return true;
  }
}
