import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.settingsgui.Commons
import qs.settingsgui.Services.Platform
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

// Extras bundles (e.g. The Ricer): curated apps, CLI/TUI tools and plugins. One Refresh
// git-pulls the ryoku-extras catalogue (and re-fetches plugins); installs run through the
// ryoku-extras-install command (packages/scripts) and PluginService (plugin items), both
// of which skip anything already present.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property bool busy: false

  property bool autoFetchTried: false
  Component.onCompleted: {
    RyokuExtras.rescan();
    firstFetchTimer.start();
  }
  Timer {
    id: firstFetchTimer
    interval: 800
    onTriggered: {
      if (!RyokuExtras.hasGit && !RyokuExtras.refreshing && !root.autoFetchTried) {
        root.autoFetchTried = true;
        RyokuExtras.refresh();
      }
    }
  }

  function availablePluginFor(id) {
    var list = PluginService.availablePlugins || [];
    for (var i = 0; i < list.length; i++)
      if (list[i].id === id)
        return list[i];
    return null;
  }

  function installPluginItem(id) {
    var meta = availablePluginFor(id);
    if (!meta) {
      ToastService.showError(qsTr("Extras"), qsTr("Plugin '%1' is not in the catalogue. Refresh and try again.").arg(id));
      return;
    }
    var key = PluginRegistry.generateCompositeKey(id, meta.source ? meta.source.url : PluginRegistry.mainSourceUrl);
    if (PluginRegistry.isPluginDownloaded(key)) {
      if (!PluginRegistry.isPluginEnabled(key))
        PluginService.enablePlugin(key);
      return;
    }
    PluginService.installPlugin(meta, false, function (ok, err, registeredKey) {
      if (ok)
        PluginService.enablePlugin(registeredKey);
      else
        ToastService.showError(qsTr("Extras"), qsTr("Failed to install %1: %2").arg(id).arg(err || qsTr("unknown error")));
    });
  }

  // Run the smart installer for packages/scripts, then hand plugin items to PluginService.
  function installBundle(bundle) {
    if (!RyokuExtras.hasGit) {
      ToastService.showNotice(qsTr("Extras"), qsTr("Refresh first to download the catalogue."));
      return;
    }
    root.busy = true;
    installProc.pendingPlugins = (bundle.items || []).filter(it => it.type === "plugin").map(it => it.name);
    installProc.command = ["ryoku-extras-install", "bundle", bundle.id];
    installProc.running = true;
  }

  function installItem(item) {
    if (item.type === "plugin") {
      installPluginItem(item.name);
      return;
    }
    if (!RyokuExtras.hasGit) {
      ToastService.showNotice(qsTr("Extras"), qsTr("Refresh first to download the catalogue."));
      return;
    }
    root.busy = true;
    installProc.pendingPlugins = [];
    installProc.command = ["ryoku-extras-install", "item", item.type, item.name];
    installProc.running = true;
  }

  Process {
    id: installProc
    property var pendingPlugins: []
    stderr: StdioCollector {}
    onExited: function (exitCode) {
      root.busy = false;
      for (var i = 0; i < pendingPlugins.length; i++)
        root.installPluginItem(pendingPlugins[i]);
      if (exitCode === 0)
        ToastService.showNotice(qsTr("Extras"), qsTr("Done. Tools already present were skipped."));
      else
        ToastService.showError(qsTr("Extras"), stderr.text.trim() || qsTr("Some items failed to install."));
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      NText {
        text: qsTr("Extras")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }
      NText {
        Layout.fillWidth: true
        text: qsTr("Curated bundles of apps, terminal tools and plugins. Installing skips anything you already have.")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }
    }

    NButton {
      text: RyokuExtras.refreshing ? qsTr("Refreshing...") : qsTr("Refresh")
      icon: "refresh"
      enabled: !RyokuExtras.refreshing
      onClicked: {
        RyokuExtras.refresh();
        PluginService.refreshAvailablePlugins();
      }
    }
  }

  NText {
    Layout.fillWidth: true
    visible: RyokuExtras.refreshError.length > 0
    text: RyokuExtras.refreshError
    pointSize: Style.fontSizeS
    color: Color.mError
    wrapMode: Text.WordWrap
  }

  RowLayout {
    Layout.fillWidth: true
    visible: RyokuExtras.refreshing || root.busy
    spacing: Style.marginM
    BusyIndicator {
      running: RyokuExtras.refreshing || root.busy
      implicitWidth: 26
      implicitHeight: 26
    }
    NText {
      Layout.fillWidth: true
      text: RyokuExtras.refreshing ? qsTr("Downloading the extras catalogue...") : qsTr("Installing - already-present tools are skipped.")
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }
  }

  NText {
    Layout.fillWidth: true
    visible: RyokuExtras.bundles.length === 0 && !RyokuExtras.refreshing
    text: qsTr("No bundles yet. Press Refresh to download the catalogue.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: RyokuExtras.bundles

    delegate: NBox {
      id: bundleCard
      required property var modelData

      Layout.fillWidth: true
      Layout.leftMargin: Style.borderS
      Layout.rightMargin: Style.borderS
      implicitHeight: Math.round(cardColumn.implicitHeight + Style.margin2L)
      color: Color.mSurface

      ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NIcon {
            icon: "package"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }
          NText {
            text: bundleCard.modelData.name || bundleCard.modelData.id
            color: Color.mPrimary
            font.weight: Style.fontWeightBold
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
          NButton {
            text: qsTr("Install all")
            icon: "download"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            enabled: !root.busy
            onClicked: root.installBundle(bundleCard.modelData)
          }
        }

        NText {
          visible: !!bundleCard.modelData.description
          text: bundleCard.modelData.description || ""
          Layout.fillWidth: true
          pointSize: Style.fontSizeXS
          color: Color.mOnSurface
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: bundleCard.modelData.items || []

          delegate: RowLayout {
            id: itemRow
            required property var modelData

            Layout.fillWidth: true
            Layout.topMargin: Style.marginXS
            spacing: Style.marginM

            NIcon {
              icon: itemRow.modelData.type === "plugin" ? "plugin" : "terminal"
              pointSize: Style.fontSizeM
              color: Color.mOnSurfaceVariant
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0
              NText {
                text: itemRow.modelData.name
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                visible: !!itemRow.modelData.summary
                text: itemRow.modelData.summary || ""
                Layout.fillWidth: true
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
              }
            }
            NIconButton {
              icon: "download"
              tooltipText: qsTr("Install just this")
              baseSize: Style.baseWidgetSize * 0.7
              enabled: !root.busy
              onClicked: root.installItem(itemRow.modelData)
            }
          }
        }
      }
    }
  }
}
