import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Modules.MainScreen
import qs.settingsgui.Services.Platform
import qs.settingsgui.Services.System
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

SmartPanel {
  id: root

  // When true, only shows step 0 with modified text for returning users (telemetry notification)
  property bool telemetryOnlyMode: false

  signal telemetryWizardCompleted

  preferredWidth: Math.round(preferredWidthRatio * 2560 * Style.uiScaleRatio)
  preferredHeight: Math.round(preferredHeightRatio * 1440 * Style.uiScaleRatio)
  preferredWidthRatio: 0.4
  preferredHeightRatio: root.telemetryOnlyMode ? 0.45 : 0.6

  panelAnchorHorizontalCenter: true
  panelAnchorVerticalCenter: true

  closeWithEscape: false

  panelContent: Item {
    id: panelContent

    // Wizard state (lazy-loaded with panelContent)
    property int currentStep: 0
    readonly property int totalSteps: root.telemetryOnlyMode ? 1 : 5
    property bool isCompleting: false

    property string selectedWallpaperDirectory: Settings.defaultWallpapersDirectory
    property string selectedWallpaper: ""
    property real selectedScaleRatio: 1.0
    property string selectedBarPosition: "top"

    Component.onCompleted: {
      selectedScaleRatio = Settings.data.general.scaleRatio;
      selectedBarPosition = Settings.data.bar.position;
      selectedWallpaperDirectory = GlobalConfig.wallpaper.directory || Settings.defaultWallpapersDirectory;
    }

    Connections {
      target: Settings
      function onSettingsSaved() {
        if (panelContent.isCompleting) {
          Logger.i("SetupWizard", "Settings saved, closing panel");
          panelContent.isCompleting = false;
          root.close();
        }
      }
    }

    Timer {
      id: closeTimer
      interval: 2000
      onTriggered: {
        if (panelContent.isCompleting) {
          Logger.w("SetupWizard", "Settings save timeout, closing panel anyway");
          panelContent.isCompleting = false;
          root.close();
        }
      }
    }

    function completeSetup() {
      if (isCompleting) {
        Logger.w("SetupWizard", "completeSetup() called while already completing, ignoring");
        return;
      }

      try {
        Logger.i("SetupWizard", root.telemetryOnlyMode ? "Completing telemetry wizard" : "Completing setup with selected options");
        isCompleting = true;

        // In telemetry-only mode, we only need to save the telemetry setting
        if (!root.telemetryOnlyMode) {
          if (typeof WallpaperService !== "undefined" && WallpaperService.refreshWallpapersList) {
            if (selectedWallpaperDirectory !== GlobalConfig.wallpaper.directory) {
              GlobalConfig.wallpaper.directory = selectedWallpaperDirectory;
              GlobalConfig.save();
              WallpaperService.refreshWallpapersList();
            }

            if (selectedWallpaper !== "") {
              WallpaperService.changeWallpaper(selectedWallpaper, undefined);
            }
          }

          Settings.data.general.scaleRatio = selectedScaleRatio;
          Settings.data.bar.position = selectedBarPosition;
        }

        // Mark the current version as seen to prevent telemetry wizard on next startup
        // (only for full setup wizard - telemetry wizard lets changelog mark it seen)
        if (!root.telemetryOnlyMode) {
          UpdateService.markChangelogSeen(UpdateService.currentVersion);
        }

        // Initialize telemetry now that user has made their choice
        TelemetryService.init();

        // Save settings immediately and wait for settingsSaved signal before closing
        Settings.saveImmediate();
        Logger.i("SetupWizard", "Setup completed successfully, waiting for settings save confirmation");

        // Emit signal for telemetry wizard completion (shell.qml will show changelog)
        if (root.telemetryOnlyMode) {
          root.telemetryWizardCompleted();
        }

        // Fallback: if settingsSaved signal doesn't fire within 2 seconds, close anyway
        closeTimer.start();
      } catch (error) {
        Logger.e("SetupWizard", "Error completing setup:", error);
        isCompleting = false;
      }
    }

    function applyWallpaperSettings() {
      if (typeof WallpaperService !== "undefined" && WallpaperService.refreshWallpapersList) {
        if (selectedWallpaperDirectory !== GlobalConfig.wallpaper.directory) {
          GlobalConfig.wallpaper.directory = selectedWallpaperDirectory;
          GlobalConfig.save();
          WallpaperService.refreshWallpapersList();
        }

        if (selectedWallpaper !== "") {
          WallpaperService.changeWallpaper(selectedWallpaper, undefined);
        }
      }
    }

    function applyUISettings() {
      Settings.data.general.scaleRatio = selectedScaleRatio;
      Settings.data.bar.position = selectedBarPosition;
    }

    ColumnLayout {
      id: wizardContent
      anchors.fill: parent
      anchors.margins: Style.marginXL
      spacing: Style.marginL

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Math.round(300 * Style.uiScaleRatio)

        StackLayout {
          id: stepStack
          anchors.fill: parent
          currentIndex: currentStep

          Item {
            ColumnLayout {
              anchors.centerIn: parent
              width: Math.round(Math.max(parent.width * 0.5, 420))
              spacing: Style.marginXL

              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                  anchors.centerIn: parent
                  width: 120
                  height: 120
                  radius: width / 2
                  color: Color.mPrimary
                  opacity: 0.08
                  scale: 1.3
                }

                Image {
                  anchors.centerIn: parent
                  width: 110
                  height: 110
                  source: Qt.resolvedUrl(Quickshell.shellDir + "/settingsgui" + "/Assets/ryoku-logo.svg")
                  fillMode: Image.PreserveAspectFit
                  smooth: true

                  Rectangle {
                    anchors.fill: parent
                    color: Color.mSurfaceVariant
                    radius: width / 2
                    border.color: Color.mOutline
                    border.width: Style.borderM
                    visible: parent.status === Image.Error

                    NIcon {
                      icon: "sparkles"
                      pointSize: Style.fontSizeXXL * 1.5
                      color: Color.mPrimary
                      anchors.centerIn: parent
                    }
                  }

                  SequentialAnimation on scale {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation {
                      from: 1.0
                      to: 1.05
                      duration: 2000
                      easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                      from: 1.05
                      to: 1.0
                      duration: 2000
                      easing.type: Easing.InOutQuad
                    }
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.marginM

                NText {
                  text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-title") : I18n.tr("setup.welcome-title")
                  pointSize: Style.fontSizeXXL * 1.4
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                }

                NText {
                  text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-subtitle") : I18n.tr("setup.welcome-subtitle")
                  pointSize: Style.fontSizeL
                  color: Color.mOnSurfaceVariant
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.topMargin: Style.marginL
                  Layout.preferredHeight: childrenRect.height + Style.margin2M
                  color: Color.mSurfaceVariant
                  radius: Style.radiusL

                  NText {
                    anchors.centerIn: parent
                    width: parent.width - Style.margin2L
                    text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-note") : I18n.tr("setup.welcome-note")
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                  }
                }
              }
            }
          }

          SetupWallpaperStep {
            id: step1
            selectedDirectory: panelContent.selectedWallpaperDirectory
            selectedWallpaper: panelContent.selectedWallpaper
            onDirectoryChanged: function (directory) {
              panelContent.selectedWallpaperDirectory = directory;
              panelContent.applyWallpaperSettings();
            }
            onWallpaperChanged: function (wallpaper) {
              panelContent.selectedWallpaper = wallpaper;
              panelContent.applyWallpaperSettings();
            }
          }

          SetupAppearanceStep {
            id: step3
          }

          SetupCustomizeStep {
            id: step2
            selectedScaleRatio: panelContent.selectedScaleRatio
            selectedBarPosition: panelContent.selectedBarPosition
            onScaleRatioChanged: function (ratio) {
              panelContent.selectedScaleRatio = ratio;
              panelContent.applyUISettings();
            }
            onBarPositionChanged: function (position) {
              panelContent.selectedBarPosition = position;
              panelContent.applyUISettings();
            }
          }

          SetupDockStep {
            id: stepDock
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Color.mOutline
        opacity: 0.2
        visible: !root.telemetryOnlyMode
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        visible: !root.telemetryOnlyMode

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginM

          Repeater {
            model: [
              {
                "icon": "sparkles",
                "label": I18n.tr("setup.welcome")
              },
              {
                "icon": "image",
                "label": I18n.tr("common.wallpaper")
              },
              {
                "icon": "palette",
                "label": I18n.tr("common.appearance")
              },
              {
                "icon": "settings",
                "label": I18n.tr("common.customize")
              },
              {
                "icon": "device-desktop",
                "label": I18n.tr("panels.dock.title")
              }
            ]
            delegate: RowLayout {
              spacing: Style.marginS

              Rectangle {
                width: 24
                height: 24
                radius: width / 2
                color: index <= currentStep ? Color.mPrimary : Color.mSurfaceVariant
                border.color: index === currentStep ? Color.mPrimary : "transparent"
                border.width: index === currentStep ? 2 : 0

                NIcon {
                  icon: modelData.icon
                  pointSize: Style.fontSizeS
                  color: index <= currentStep ? Color.mOnPrimary : Color.mOnSurfaceVariant
                  anchors.centerIn: parent
                }

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationNormal
                  }
                }
              }

              NText {
                text: modelData.label
                pointSize: Style.fontSizeS
                color: index <= currentStep ? Color.mPrimary : Color.mOnSurfaceVariant
                font.weight: index === currentStep ? Style.fontWeightBold : Style.fontWeightRegular

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationNormal
                  }
                }
              }

              Rectangle {
                width: 40
                height: 2
                radius: 1
                color: index < currentStep ? Color.mPrimary : Color.mSurfaceVariant
                visible: index < totalSteps - 1

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationNormal
                  }
                }
              }
            }
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.topMargin: Style.marginS

        RowLayout {
          anchors.fill: parent
          spacing: Style.marginM

          NButton {
            text: I18n.tr("setup.skip-setup")
            outlined: true
            visible: !root.telemetryOnlyMode
            Layout.preferredHeight: 44
            onClicked: {
              panelContent.completeSetup();
            }
          }

          Item {
            Layout.fillWidth: true
          }

          NButton {
            text: "← " + I18n.tr("common.back")
            outlined: true
            visible: currentStep > 0 && !root.telemetryOnlyMode
            Layout.preferredHeight: 44
            onClicked: {
              if (currentStep > 0) {
                currentStep--;
              }
            }
          }

          NButton {
            text: root.telemetryOnlyMode ? I18n.tr("setup.telemetry-wizard-done") : (currentStep === totalSteps - 1 ? I18n.tr("setup.all-done") : I18n.tr("common.continue") + " →")
            Layout.preferredHeight: 44
            onClicked: {
              if (currentStep < totalSteps - 1) {
                currentStep++;
              } else {
                panelContent.completeSetup();
              }
            }
          }
        }
      }
    }
  }
}
