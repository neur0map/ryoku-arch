import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Services.Media
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Preferred player
  NTextInput {
    // RYOKU WIRED: GlobalConfig.services.defaultPlayer (serviceconfig.hpp:32)
    label: I18n.tr("panels.audio.media-primary-player-label")
    description: I18n.tr("panels.audio.media-primary-player-description")
    placeholderText: I18n.tr("panels.audio.media-primary-player-placeholder")
    text: GlobalConfig.services.defaultPlayer
    onTextChanged: {
      GlobalConfig.services.defaultPlayer = text;
      GlobalConfig.save();
    }
  }

}
