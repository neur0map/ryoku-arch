import QtQuick
import Ryoku.Config
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Services.Platform
import qs.settingsgui.Services.System
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets
import qs.services

ColumnLayout {
  id: root
  opacity: 0

  onSystemInfoLoadingChanged: {
    if (!systemInfoLoading)
      tabAppearAnim.start();
  }

  NumberAnimation on opacity {
    id: tabAppearAnim
    from: 0
    to: 1
    duration: Style.animationSlowest
    easing.type: Easing.OutCubic
    running: false
  }

  // RYOKU: surface update-check and update-start results as toasts so the
  // System Updates actions always give visible success/error feedback.
  Connections {
    target: RyokuAbout

    function onUpdateCheckFinished(report) {
      if (report && report.ok === false)
        ToastService.showError("Update check failed", (report.error || "Could not reach the update channel").toString());
    }
    function onUpdateStartFinished(report) {
      if (report && report.ok)
        ToastService.showNotice("Update", (report.message || "Update started in a terminal.").toString());
      else
        ToastService.showError("Update failed to start", ((report && report.error) || "Could not start the update.").toString());
    }
  }

  property string latestVersion: GitHubService.latestVersion
  // RYOKU: the version is Ryoku's, from the RyokuAbout helper; never the upstream
  // UpdateService string.
  property string currentVersion: (RyokuAbout.info && RyokuAbout.info.version) ? RyokuAbout.info.version : ""
  property string commitInfo: ""
  property string qsVersion: ""
  property string qsRevision: ""

  readonly property bool isGitVersion: root.currentVersion.endsWith("-git")
  readonly property int gigaB: (1024 * 1024 * 1024)
  readonly property int gigaD: (1000 * 1000 * 1000)

  readonly property bool updateAvailable: {
    if (!root.latestVersion || !root.currentVersion || root.latestVersion === I18n.tr("common.unknown"))
      return false;
    return UpdateService.compareVersions(root.latestVersion, root.currentVersion) > 0 && !root.isGitVersion;
  }
  readonly property bool isUpToDate: {
    if (!root.latestVersion || !root.currentVersion || root.latestVersion === I18n.tr("common.unknown"))
      return false;
    return UpdateService.compareVersions(root.latestVersion, root.currentVersion) <= 0;
  }

  readonly property bool qsUpdateAvailable: {
    if (!GitHubService.latestQSVersion || !root.qsVersion || GitHubService.latestQSVersion === I18n.tr("common.unknown"))
      return false;
    return UpdateService.compareVersions(GitHubService.latestQSVersion, root.qsVersion) > 0;
  }

  readonly property bool qsIsUpToDate: {
    if (!GitHubService.latestQSVersion || !root.qsVersion || GitHubService.latestQSVersion === I18n.tr("common.unknown"))
      return false;
    return UpdateService.compareVersions(GitHubService.latestQSVersion, root.qsVersion) <= 0;
  }

  property var systemInfo: null
  property bool systemInfoLoading: true
  property bool systemInfoAvailable: true

  spacing: Style.marginL

  function getModule(type) {
    if (!root.systemInfo)
      return null;
    return root.systemInfo.find(m => m.type === type);
  }

  function getMonitorsText(separator) {
    const sep = separator || "\n";
    const screens = Quickshell.screens || [];
    const scales = CompositorService.displayScales || {};
    let lines = [];
    for (let i = 0; i < screens.length; i++) {
      const screen = screens[i];
      const name = screen.name || "Unknown";
      const scaleData = scales[name];
      const scaleValue = (typeof scaleData === "object" && scaleData !== null) ? (scaleData.scale || 1.0) : (scaleData || 1.0);
      lines.push(name + ": " + screen.width + "x" + screen.height + " @ " + scaleValue + "x");
    }
    return lines.join(sep);
  }

  function getTelemetryPayload() {
    const screens = Quickshell.screens || [];
    const scales = CompositorService.displayScales || {};
    const monitors = [];
    for (let i = 0; i < screens.length; i++) {
      const screen = screens[i];
      const name = screen.name || "Unknown";
      const scaleData = scales[name];
      const scaleValue = (typeof scaleData === "object" && scaleData !== null) ? (scaleData.scale || 1.0) : (scaleData || 1.0);
      monitors.push({
                      width: screen.width || 0,
                      height: screen.height || 0,
                      scale: scaleValue
                    });
    }
    return {
      instanceId: TelemetryService.getInstanceId(),
      version: root.currentVersion,
      compositor: TelemetryService.getCompositorType(),
      os: HostService.osPretty || "Unknown",
      ramGb: Math.round((root.getModule("Memory")?.result?.total || 0) / root.gigaB),
      monitors: monitors,
      ui: {
        scaleRatio: GlobalConfig.general.scaleRatio,
        fontDefaultScale: Settings.data.ui.fontDefaultScale,
        fontFixedScale: Settings.data.ui.fontFixedScale
      }
    };
  }

  function copyTelemetryData() {
    const payload = getTelemetryPayload();
    const json = JSON.stringify(payload, null, 2);
    Quickshell.execDetached(["wl-copy", json]);
    ToastService.showNotice(I18n.tr("panels.about.telemetry-title"), I18n.tr("panels.about.telemetry-data-copied"));
  }

  function copyInfoToClipboard() {
    let info = "Ryoku Shell: " + root.currentVersion;
    if (root.isGitVersion && root.commitInfo) {
      info += " (" + root.commitInfo + ")";
    }
    info += "\n";

    if (root.qsVersion) {
      let qsV = root.qsVersion.startsWith("v") ? root.qsVersion : "v" + root.qsVersion;
      info += "Quickshell: " + qsV;
      if (root.qsRevision) {
        info += " (" + root.qsRevision + ")";
      }
      info += "\n";
    }

    info += "\nSystem Information\n";
    info += "==================\n";
    if (root.systemInfo) {
      const os = root.getModule("OS");
      const kernel = root.getModule("Kernel");
      const title = root.getModule("Title");
      const product = root.getModule("Host");
      const board = root.getModule("Board");
      const cpu = root.getModule("CPU");
      const gpu = root.getModule("GPU");
      const mem = root.getModule("Memory");
      const wm = root.getModule("WM");
      info += "OS: " + (os?.result?.prettyName || "N/A") + "\n";
      info += "Kernel: " + (kernel?.result?.release || "N/A") + "\n";
      info += "Host: " + (title?.result?.hostName || "N/A") + "\n";
      info += "Product: " + (product?.result?.name || "N/A") + "\n";
      info += "Board: " + (board?.result?.name || "N/A") + "\n";
      info += "CPU: " + (cpu?.result?.cpu || "N/A") + "\n";
      if (gpu?.result && Array.isArray(gpu.result) && gpu.result.length > 0) {
        info += "GPU: " + gpu.result.map(g => g.name || "Unknown").join(", ") + "\n";
      }
      if (mem?.result) {
        info += "Memory: " + (mem.result.total / root.gigaB).toFixed(1) + " GB \n";
      }
      if (wm?.result) {
        info += "WM: " + (wm.result.prettyName || wm.result.processName || "N/A") + "\n";
      }
    }
    const monitors = getMonitorsText("\n").split("\n");
    for (const mon of monitors) {
      info += "Monitor: " + mon + "\n";
    }
    info += "\nSettings\n";
    info += "========\n";
    info += "UI Scale: " + GlobalConfig.general.scaleRatio + "\n";
    info += "Default Font: " + (Settings.data.ui.fontDefault || "default") + " @ " + Settings.data.ui.fontDefaultScale + "x\n";
    info += "Fixed Font: " + (Settings.data.ui.fontFixed || "default") + " @ " + Settings.data.ui.fontFixedScale + "x\n";
    Quickshell.execDetached(["wl-copy", info]);
    ToastService.showNotice(I18n.tr("panels.about.title"), I18n.tr("panels.about.info-copied"));
  }

  Component.onCompleted: {
    // RYOKU: pull real ryoku version/channel, and auto-check for updates so the
    // System Updates panel shows live status the moment About opens.
    RyokuAbout.refreshStatus();
    RyokuAbout.checkUpdates();
    checkFastfetchProcess.running = true;
    // RYOKU: qsVersion intentionally left empty so the QS-version row stays hidden.

    Logger.d("VersionSubTab", "Current version:", root.currentVersion);
    Logger.d("VersionSubTab", "Is git version:", root.isGitVersion);
    // Only fetch commit info for -git versions
    if (root.isGitVersion) {
      fetchGitCommit();
    }
  }

  function fetchGitCommit() {
    var shellDir = Quickshell.shellDir + "/settingsgui" || "";
    Logger.d("VersionSubTab", "fetchGitCommit - shellDir:", shellDir);
    if (!shellDir) {
      Logger.d("VersionSubTab", "fetchGitCommit - Cannot determine shell directory, skipping git commit fetch");
      return;
    }

    gitProcess.workingDirectory = shellDir;
    gitProcess.running = true;
  }

  Process {
    id: gitProcess
    command: ["git", "rev-parse", "--short", "HEAD"]
    running: false

    onExited: function (exitCode) {
      Logger.d("VersionSubTab", "gitProcess - Process exited with code:", exitCode);
      if (exitCode === 0) {
        var gitOutput = stdout.text.trim();
        Logger.d("VersionSubTab", "gitProcess - gitOutput:", gitOutput);
        if (gitOutput) {
          root.commitInfo = gitOutput;
          Logger.d("VersionSubTab", "gitProcess - Set commitInfo to:", root.commitInfo);
        }
      } else {
        Logger.d("VersionSubTab", "gitProcess - Git command failed. Exit code:", exitCode);
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: checkFastfetchProcess
    command: ["sh", "-c", "command -v fastfetch"]
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        Logger.d("VersionSubTab", "fastfetch found, running it");
        fastfetchProcess.running = true;
      } else {
        Logger.w("VersionSubTab", "fastfetch not found");
        root.systemInfoLoading = false;
        root.systemInfoAvailable = false;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: fastfetchProcess
    command: ["fastfetch", "--format", "json", "--config", Quickshell.shellDir + "/settingsgui" + "/Assets/Services/fastfetch/system-info.jsonc"]
    running: false

    onExited: function (exitCode) {
      root.systemInfoLoading = false;
      if (exitCode === 0) {
        try {
          root.systemInfo = JSON.parse(stdout.text);
          root.systemInfoAvailable = true;
        } catch (e) {
          Logger.w("VersionSubTab", "Failed to parse fastfetch JSON: " + e);
          root.systemInfoAvailable = false;
        }
      } else {
        root.systemInfoAvailable = false;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Ryoku identity — logo, name, version (centered)
  ColumnLayout {
    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    spacing: Style.marginXS

    Image {
      source: "../../../../../Assets/ryoku-logo.svg"
      Layout.preferredWidth: 80 * Style.uiScaleRatio
      Layout.preferredHeight: Layout.preferredWidth
      Layout.alignment: Qt.AlignHCenter
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Layout.preferredWidth
      sourceSize.height: Layout.preferredHeight
      mipmap: true
      smooth: true
      rotation: Settings.isDebug ? 180 : 0

      Behavior on rotation {
        NumberAnimation {
          duration: Style.animationSlowest
          easing.type: Easing.OutBack
        }
      }

      property int debugTapCount: 0

      Timer {
        id: debugTapTimer
        interval: 5000
        onTriggered: parent.debugTapCount = 0
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          if (parent.debugTapCount === 0)
            debugTapTimer.restart();
          parent.debugTapCount++;
          if (parent.debugTapCount >= 8) {
            parent.debugTapCount = 0;
            debugTapTimer.stop();
            Settings.isDebug = !Settings.isDebug;
            ToastService.showNotice("Debug", I18n.tr(Settings.isDebug ? "panels.about.debug-enabled" : "panels.about.debug-disabled"));
          }
        }
      }
    }

    NText {
      text: "Ryoku"
      pointSize: Style.fontSizeXL
      font.weight: Style.fontWeightSemiBold
      color: Color.mPrimary
      Layout.alignment: Qt.AlignHCenter
    }

    NText {
      // RYOKU: single clean version line (helper version already includes the
      // commit). Ryoku update status lives in the System Updates section below.
      text: (RyokuAbout.info && RyokuAbout.info.version) ? RyokuAbout.info.version : (root.currentVersion.length > 0 ? root.currentVersion : "—")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      Layout.alignment: Qt.AlignHCenter
    }
  }

  GridLayout {
    id: actionsGrid
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
    rowSpacing: Style.marginM
    columnSpacing: Style.marginM

    columns: (changelogBtn.implicitWidth + copyBtn.implicitWidth + supportBtn.implicitWidth + 2 * columnSpacing) < root.width ? 3 : 1

    NButton {
      id: changelogBtn
      icon: "sparkles"
      text: I18n.tr("panels.about.changelog")
      outlined: true
      Layout.alignment: Qt.AlignHCenter
      onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/neur0map/ryoku-arch/blob/main/CHANGELOG.md"])
    }

    NButton {
      id: copyBtn
      icon: "copy"
      text: I18n.tr("panels.about.copy-info")
      outlined: true
      Layout.alignment: Qt.AlignHCenter
      onClicked: root.copyInfoToClipboard()
    }

    NButton {
      id: supportBtn
      icon: "heart"
      text: I18n.tr("panels.about.support")
      outlined: true
      Layout.alignment: Qt.AlignHCenter
      onClicked: Quickshell.execDetached(["xdg-open", "https://ko-fi.com/ryokuarch"])
    }
  }

  // RYOKU: removed the upstream changelog-on-startup toggle (no ryoku backend).

  // RYOKU: System updates / maintenance — wired to the RyokuAbout service.
  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
  }

  NHeader {
    label: "System Updates"
    description: (RyokuAbout.info && RyokuAbout.info.configuredChannelLabel) ? ("Release channel: " + RyokuAbout.info.configuredChannelLabel) : "Keep ryoku up to date"
  }

  NText {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    text: {
      const u = RyokuAbout.lastUpdateReport || ({});
      if (RyokuAbout.checkingUpdates)
        return "Checking for updates…";
      if (u.updateStateDetail)
        return u.updateStateDetail;
      const inc = (u.incoming || []).length;
      if (inc > 0)
        return inc + " incoming change(s) available — choose Update now.";
      if (u.ok === true)
        return "ryoku is up to date.";
      return "Check for updates to see what's available on your channel.";
    }
  }

  // RYOKU: collapsible drawer listing the incoming commit descriptions
  // (from check-updates' `incoming` array). Shown only when updates exist.
  NCollapsible {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginXS
    visible: !!(RyokuAbout.lastUpdateReport && RyokuAbout.lastUpdateReport.incoming && RyokuAbout.lastUpdateReport.incoming.length > 0)
    label: {
      const n = (RyokuAbout.lastUpdateReport && RyokuAbout.lastUpdateReport.incoming) ? RyokuAbout.lastUpdateReport.incoming.length : 0;
      return "View " + n + (n === 1 ? " incoming change" : " incoming changes");
    }

    Repeater {
      model: (RyokuAbout.lastUpdateReport && RyokuAbout.lastUpdateReport.incoming) || []

      delegate: ColumnLayout {
        required property var modelData

        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: modelData.subject || ""
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightMedium
          wrapMode: Text.WordWrap
        }
        NText {
          Layout.fillWidth: true
          text: (modelData.hash || "") + "  ·  " + (modelData.author || "") + "  ·  " + (modelData.relativeTime || "")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  GridLayout {
    id: updatesGrid
    Layout.fillWidth: true
    Layout.topMargin: Style.marginXS
    columns: 2
    rowSpacing: Style.marginS
    columnSpacing: Style.marginS

    NButton {
      id: checkBtn
      Layout.fillWidth: true
      icon: "refresh"
      text: RyokuAbout.checkingUpdates ? "Checking…" : "Check for updates"
      outlined: true
      enabled: !RyokuAbout.checkingUpdates
      onClicked: RyokuAbout.checkUpdates()
    }

    NButton {
      id: updateBtn
      Layout.fillWidth: true
      // RYOKU: one updater. Always offer it — clicking opens the terminal and runs
      // ryoku-update (Ryoku + system + AUR), which reports when there is nothing to do.
      // Gating visibility on the Ryoku git delta hid the action whenever the shell was current.
      visible: true
      icon: "arrow-up-circle"
      text: RyokuAbout.startingUpdate ? "Updating…" : "Update now"
      enabled: !RyokuAbout.startingUpdate
      onClicked: RyokuAbout.startUpdate((RyokuAbout.lastUpdateReport && RyokuAbout.lastUpdateReport.updateBranch) || (RyokuAbout.info && RyokuAbout.info.updateBranch) || (RyokuAbout.info && RyokuAbout.info.configuredChannel) || "")
    }

  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: I18n.tr("panels.about.system-title")
  }

  // Error state (fastfetch not installed)
  ColumnLayout {
    visible: !root.systemInfoAvailable
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: I18n.tr("panels.about.system-not-installed")
      color: Color.mOnSurfaceVariant
    }

    NText {
      text: I18n.tr("panels.about.system-install-hint")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
    }
  }

  GridLayout {
    id: sysInfo
    readonly property real textSize: Style.fontSizeS

    visible: root.systemInfoAvailable && root.systemInfo
    Layout.fillWidth: true
    columns: 2
    rowSpacing: Style.marginXS
    columnSpacing: Style.marginM

    NText {
      text: I18n.tr("panels.about.system-os")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const os = root.getModule("OS");
        return os?.result?.prettyName || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-kernel")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const kernel = root.getModule("Kernel");
        return kernel?.result?.release || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-host")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const title = root.getModule("Title");
        return title?.result?.hostName || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-product")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const title = root.getModule("Host");
        return title?.result?.name || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-board")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const title = root.getModule("Board");
        return title?.result?.name || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-uptime")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const value = root.getModule("Uptime")?.result?.uptime;
        return value ? Time.formatVagueHumanReadableDuration(value / 1000) : "-";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-cpu")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const cpu = root.getModule("CPU");
        if (!cpu?.result)
          return "N/A";
        let cpuText = cpu.result.cpu || "N/A";
        const cores = cpu.result.cores;
        if (cores?.logical) {
          cpuText += " (" + cores.logical + " threads)";
        }
        return cpuText;
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-gpu")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const gpu = root.getModule("GPU");
        if (!gpu?.result || !Array.isArray(gpu.result) || gpu.result.length === 0)
          return "N/A";
        return gpu.result.map(g => g.name || "Unknown").join(", ");
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-memory")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const mem = root.getModule("Memory");
        if (!mem?.result)
          return "N/A";
        const used = (mem.result.used / root.gigaB).toFixed(1);
        const total = (mem.result.total / root.gigaB).toFixed(1);
        return used + " GiB / " + total + " GiB";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-disk")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const disk = root.getModule("Disk");
        if (!disk?.result || !Array.isArray(disk.result) || disk.result.length === 0)
          return "N/A";
        const rootDisk = disk.result.find(d => d.mountpoint === "/");
        if (!rootDisk?.bytes)
          return "N/A";
        const used = (rootDisk.bytes.used / root.gigaD).toFixed(1);
        const total = (rootDisk.bytes.total / root.gigaD).toFixed(1);
        return used + " GB / " + total + " GB" + " (" + rootDisk.filesystem + ")";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-wm")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const wm = root.getModule("WM");
        if (!wm?.result)
          return "N/A";
        let wmText = wm.result.prettyName || wm.result.processName || "N/A";
        if (wm.result.protocolName) {
          wmText += " (" + wm.result.protocolName + ")";
        }
        return wmText;
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      text: I18n.tr("panels.about.system-packages")
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const pkg = root.getModule("Packages");
        if (!pkg?.result)
          return "N/A";
        const result = pkg.result;
        if (result.all) {
          const managers = [];
          if (result.rpm > 0)
            managers.push("rpm: " + result.rpm);
          if (result.pacman > 0)
            managers.push("pacman: " + result.pacman);
          if (result.dpkg > 0)
            managers.push("dpkg: " + result.dpkg);
          if (result.flatpakSystem > 0 || result.flatpakUser > 0) {
            const flatpak = (result.flatpakSystem || 0) + (result.flatpakUser || 0);
            managers.push("flatpak: " + flatpak);
          }
          if (result.snap > 0)
            managers.push("snap: " + result.snap);
          if (result.nixSystem > 0 || result.nixUser > 0 || result.nixDefault > 0) {
            const nix = (result.nixSystem || 0) + (result.nixUser || 0) + (result.nixDefault || 0);
            managers.push("nix: " + nix);
          }
          if (result.brew > 0)
            managers.push("brew: " + result.brew);
          if (managers.length > 0) {
            return result.all + " (" + managers.join(", ") + ")";
          }
          return result.all.toString();
        }
        return "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Monitors (2 items per screen: label + value)
    Repeater {
      model: Quickshell.screens.length * 2

      NText {
        readonly property int screenIndex: Math.floor(index / 2)
        readonly property bool isLabel: index % 2 === 0
        readonly property var screen: Quickshell.screens[screenIndex]

        text: {
          if (isLabel)
            return I18n.tr("panels.about.system-monitor");
          const name = screen?.name || "Unknown";
          const scales = CompositorService.displayScales || {};
          const scaleData = scales[name];
          const scaleValue = (typeof scaleData === "object" && scaleData !== null) ? (scaleData.scale || 1.0) : (scaleData || 1.0);
          return name + ": " + (screen?.width || 0) + "x" + (screen?.height || 0) + " @ " + scaleValue + "x";
        }
        color: isLabel ? Color.mOnSurfaceVariant : Color.mOnSurface
        pointSize: sysInfo.textSize
        Layout.fillWidth: !isLabel
        wrapMode: Text.Wrap
      }
    }
  }

  // RYOKU: removed the upstream telemetry + privacy-policy section (ryoku has no telemetry).
}
