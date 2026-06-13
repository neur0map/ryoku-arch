import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen

  enabled: GlobalConfig.wallpaper.enabled
  icon: "wallpaper-selector"
  tooltipText: I18n.tr("wallpaper.panel.title")
  onClicked: PanelService.getPanel("wallpaperPanel", screen)?.toggle()
  onRightClicked: WallpaperService.setRandomWallpaper()
}
