import QtQuick
import Quickshell
import qs.Noctalia.Commons

QtObject {
  id: root

  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Skipping upstream color scheme migration in Ryoku runtime");
    return true;
  }
}
