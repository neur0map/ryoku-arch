import QtQuick

QtObject {
  id: root

  // Migrate TaskbarGrouped widgets to Workspace with showApplications: true
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v28");

    // Check bar widgets in all sections
    const sections = ["left", "center", "right"];

    for (const section of sections) {
      if (!rawJson?.bar?.widgets?.[section])
        continue;

      const widgets = rawJson.bar.widgets[section];
      for (let i = 0; i < widgets.length; i++) {
        if (widgets[i].id === "TaskbarGrouped") {
          // Convert TaskbarGrouped to Workspace with showApplications
          const oldWidget = widgets[i];
          adapter.bar.widgets[section][i] = {
            id: "Workspace",
            showApplications: true,
            labelMode: oldWidget.labelMode || "index",
            hideUnoccupied: oldWidget.hideUnoccupied || false,
            showLabelsOnlyWhenOccupied: oldWidget.showLabelsOnlyWhenOccupied ?? true,
            colorizeIcons: oldWidget.colorizeIcons || false
          };
          logger.i("Settings", "Migrated TaskbarGrouped to Workspace in " + section + " section");
        }
      }
    }

    return true;
  }
}
