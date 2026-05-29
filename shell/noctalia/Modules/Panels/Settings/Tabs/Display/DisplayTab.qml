import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.noctalia.Commons
import qs.noctalia.Services.Location
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: 0

  // Time dropdown options (00:00 .. 23:30)
  ListModel {
    id: timeOptions
  }

  function populateTimeOptions() {
    for (var h = 0; h < 24; h++) {
      for (var m = 0; m < 60; m += 30) {
        var hh = ("0" + h).slice(-2);
        var mm = ("0" + m).slice(-2);
        var key = hh + ":" + mm;
        timeOptions.append({
                             "key": key,
                             "name": key
                           });
      }
    }
  }

  Component.onCompleted: {
    Qt.callLater(populateTimeOptions);
  }

  // Check for wlsunset availability when enabling Night Light
  Process {
    id: wlsunsetCheck
    command: ["sh", "-c", "command -v wlsunset"]
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        Settings.data.nightLight.enabled = true;
        NightLightService.apply();
        ToastService.showNotice(I18n.tr("common.night-light"), I18n.tr("common.enabled"), "nightlight-on");
      } else {
        Settings.data.nightLight.enabled = false;
        ToastService.showWarning(I18n.tr("common.night-light"), I18n.tr("toast.night-light.not-installed"));
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: I18n.tr("panels.display.layout-title")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: I18n.tr("common.brightness")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
    NTabButton {
      text: I18n.tr("common.night-light")
      tabIndex: 2
      checked: subTabBar.currentIndex === 2
      opacity: 0.6 // RYOKU: greyed preview marker — night light (wlsunset) not wired yet
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    MonitorsSubTab {}
    BrightnessSubTab {}
    // RYOKU: night light (wlsunset) not wired in ryoku yet — greyed, non-interactive preview (still viewable)
    NightLightSubTab {
      enabled: false
      opacity: 0.45
      timeOptions: timeOptions
      onCheckWlsunset: wlsunsetCheck.running = true
    }
  }
}
