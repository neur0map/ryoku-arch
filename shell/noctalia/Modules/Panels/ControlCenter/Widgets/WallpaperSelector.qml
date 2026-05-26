import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

NIconButtonHot {
  property ShellScreen screen

  enabled: Settings.data.wallpaper.enabled
  icon: "wallpaper-selector"
  tooltipText: I18n.tr("wallpaper.panel.title")
  onClicked: PanelService.getPanel("wallpaperPanel", screen)?.toggle()
  onRightClicked: WallpaperService.setRandomWallpaper()
}
