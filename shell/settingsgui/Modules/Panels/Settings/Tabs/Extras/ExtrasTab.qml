import QtQuick
import QtQuick.Layouts
import qs.services
import qs.settingsgui.Commons
import qs.settingsgui.Services.Platform
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

// Extras bundles (e.g. The Ricer): curated apps, CLI/TUI tools and plugins.
//
// Each item shows its own state - already present, installing (loader), installed
// (check) or failed (with the reason) - mirroring the Plugins tab. Package/script
// items install through RyokuExtras, which runs ryoku-extras-install in a floating
// terminal (so the sudo/yay prompt has a TTY) and reports per-item results back.
// Plugin items go through PluginService, exactly like Settings -> Plugins.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property bool autoFetchTried: false
  // Bumped when plugin availability/installs change so the plugin-item state below re-evaluates.
  property int pluginCounter: 0

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

  Connections {
    target: PluginService
    function onAvailablePluginsUpdated() {
      root.pluginCounter++;
    }
  }
  Connections {
    target: PluginRegistry
    function onPluginsChanged() {
      root.pluginCounter++;
    }
  }

  // --- plugin items (handled by PluginService, like the Plugins tab) ---
  function availablePluginFor(id) {
    var list = PluginService.availablePlugins || [];
    for (var i = 0; i < list.length; i++)
      if (list[i].id === id)
        return list[i];
    return null;
  }

  function pluginKey(id) {
    var meta = availablePluginFor(id);
    if (!meta)
      return "";
    return PluginRegistry.generateCompositeKey(id, meta.source ? meta.source.url : PluginRegistry.mainSourceUrl);
  }

  function pluginDownloaded(id) {
    void root.pluginCounter;
    var key = pluginKey(id);
    return key ? PluginRegistry.isPluginDownloaded(key) : false;
  }

  function pluginInstalling(id) {
    return PluginService.installingPlugins[id] === true;
  }

  function installPluginItem(id) {
    var meta = availablePluginFor(id);
    if (!meta) {
      ToastService.showError(qsTr("Extras"), qsTr("Plugin '%1' is not in the catalogue yet. Refresh and try again.").arg(id));
      return;
    }
    var key = PluginRegistry.generateCompositeKey(id, meta.source ? meta.source.url : PluginRegistry.mainSourceUrl);
    if (PluginRegistry.isPluginDownloaded(key)) {
      if (!PluginRegistry.isPluginEnabled(key))
        PluginService.enablePlugin(key);
      return;
    }
    PluginService.installPlugin(meta, false, function (ok, err, registeredKey) {
      root.pluginCounter++;
      if (ok)
        PluginService.enablePlugin(registeredKey);
      else
        ToastService.showError(qsTr("Extras"), qsTr("Failed to install %1: %2").arg(id).arg(err || qsTr("unknown error")));
    });
  }

  // --- package/script items (handled by RyokuExtras) ---
  // -> "present" | "installing" | "installed" | "failed" | "idle"
  function pkgState(name) {
    if (RyokuExtras.installing[name] === true)
      return "installing";
    if (RyokuExtras.presence[name] === true)
      return "present";
    var r = RyokuExtras.results[name];
    if (r && r.status === "installed")
      return "present";
    if (r && r.status === "failed")
      return "failed";
    return "idle";
  }

  function pkgError(name) {
    var r = RyokuExtras.results[name];
    return (r && r.error) ? r.error : qsTr("Install failed - see the terminal output.");
  }

  // -> "downloaded" | "installing" | "idle"
  function itemState(item) {
    if (item.type === "plugin")
      return pluginInstalling(item.name) ? "installing" : (pluginDownloaded(item.name) ? "present" : "idle");
    return pkgState(item.name);
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
    if (!RyokuExtras.installItem(item.type, item.name))
      ToastService.showNotice(qsTr("Extras"), qsTr("Another install is already running."));
  }

  function installBundle(bundle) {
    if (!RyokuExtras.hasGit) {
      ToastService.showNotice(qsTr("Extras"), qsTr("Refresh first to download the catalogue."));
      return;
    }
    var items = bundle.items || [];
    for (var i = 0; i < items.length; i++)
      if (items[i].type === "plugin")
        installPluginItem(items[i].name);
    RyokuExtras.installBundle(bundle.id);
  }

  function uninstallPluginItem(id) {
    var key = pluginKey(id);
    if (!key)
      return;
    PluginService.uninstallPlugin(key, function (ok, err) {
      root.pluginCounter++;
      if (!ok)
        ToastService.showError(qsTr("Extras"), qsTr("Failed to remove %1: %2").arg(id).arg(err || qsTr("unknown error")));
    });
  }

  function uninstallItem(item) {
    if (item.type === "plugin") {
      uninstallPluginItem(item.name);
      return;
    }
    if (!RyokuExtras.uninstallItem(item.type, item.name))
      ToastService.showNotice(qsTr("Extras"), qsTr("Another task is already running."));
  }

  function uninstallBundle(bundle) {
    var items = bundle.items || [];
    for (var i = 0; i < items.length; i++)
      if (items[i].type === "plugin" && pluginDownloaded(items[i].name))
        uninstallPluginItem(items[i].name);
    RyokuExtras.uninstallBundle(bundle.id);
  }

  // --- header ---
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
        text: qsTr("Curated bundles of apps, terminal tools and plugins. Already-installed tools are skipped.")
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

  // --- live status banner ---
  RowLayout {
    Layout.fillWidth: true
    visible: RyokuExtras.refreshing || RyokuExtras.busy
    spacing: Style.marginM
    NBusyIndicator {
      size: Style.baseWidgetSize * 0.7
      running: visible
    }
    NText {
      Layout.fillWidth: true
      text: RyokuExtras.refreshing ? qsTr("Downloading the extras catalogue...") : qsTr("Installing in the terminal window - enter your password there if prompted.")
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

  // --- bundle cards ---
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
            text: qsTr("Uninstall all")
            icon: "trash"
            enabled: !RyokuExtras.busy && !RyokuExtras.refreshing
            onClicked: root.uninstallBundle(bundleCard.modelData)
          }
          NButton {
            text: qsTr("Install all")
            icon: "download"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            enabled: !RyokuExtras.busy && !RyokuExtras.refreshing
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
            readonly property string installState: root.itemState(itemRow.modelData)

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

            // present -> check
            NIcon {
              visible: itemRow.installState === "present"
              icon: "circle-check"
              pointSize: Style.baseWidgetSize * 0.5
              color: Color.mPrimary
            }

            // present -> uninstall (packages + plugins; scripts cannot be auto-removed)
            NIconButton {
              visible: itemRow.installState === "present" && itemRow.modelData.type !== "script"
              icon: "trash"
              tooltipText: qsTr("Uninstall")
              baseSize: Style.baseWidgetSize * 0.7
              enabled: !RyokuExtras.busy
              onClicked: root.uninstallItem(itemRow.modelData)
            }

            // installing -> loader
            NBusyIndicator {
              visible: itemRow.installState === "installing"
              size: Style.baseWidgetSize * 0.5
              running: visible
            }

            // failed -> reason + retry
            NText {
              visible: itemRow.installState === "failed"
              text: qsTr("Failed")
              pointSize: Style.fontSizeXXS
              color: Color.mError
            }
            NIconButton {
              visible: itemRow.installState === "failed"
              icon: "refresh"
              tooltipText: root.pkgError(itemRow.modelData.name)
              colorBg: Color.mError
              colorFg: Color.mOnError
              baseSize: Style.baseWidgetSize * 0.7
              enabled: !RyokuExtras.busy
              onClicked: root.installItem(itemRow.modelData)
            }

            // idle -> install
            NIconButton {
              visible: itemRow.installState === "idle"
              icon: "download"
              tooltipText: qsTr("Install just this")
              baseSize: Style.baseWidgetSize * 0.7
              enabled: !RyokuExtras.busy
              onClicked: root.installItem(itemRow.modelData)
            }
          }
        }
      }
    }
  }
}
