import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Services.System
import qs.noctalia.Widgets
import qs.utils

ColumnLayout {
  id: root

  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string avatarPath: homeDir.length > 0 ? (homeDir + "/.face") : ""
  // settable so we can clear-then-reset to force a reload after ~/.face changes
  property string avatarSource: avatarPath

  // System font families for the pickers (Qt built-in; FontService isn't in ryoku)
  ListModel {
    id: fontModel
  }
  Component.onCompleted: {
    const fams = Qt.fontFamilies();
    for (let i = 0; i < fams.length; i++)
      fontModel.append({
        "key": fams[i],
        "name": fams[i]
      });
  }

  NFilePicker {
    id: facePicker
    title: I18n.tr("panels.general.profile-tooltip")
    selectionMode: "files"
    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp"]
    onAccepted: paths => {
      if (paths.length > 0 && root.homeDir.length > 0) {
        // RYOKU: profile picture lives at ~/.face (same as the dashboard face picker)
        CUtils.copyFile(Qt.resolvedUrl(paths[0]), Qt.resolvedUrl(root.homeDir + "/.face"));
        // force the avatar image to reload the same-path, new-content file
        root.avatarSource = "";
        Qt.callLater(() => root.avatarSource = root.avatarPath);
      }
    }
  }

  // Profile — RYOKU WIRED: avatar = ~/.face
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginL

    NImageRounded {
      Layout.preferredWidth: 128 * Style.uiScaleRatio
      Layout.preferredHeight: width
      radius: width / 2
      imagePath: root.avatarSource
      fallbackIcon: "person"
      borderColor: Color.mPrimary
      borderWidth: Style.borderM
      Layout.alignment: Qt.AlignTop
    }

    ColumnLayout {
      NText {
        text: HostService.displayName
        pointSize: Style.fontSizeM
        color: Color.mPrimary
      }

      NTextInputButton {
        label: I18n.tr("panels.general.profile-picture-label")
        description: I18n.tr("panels.general.profile-picture-description")
        text: root.avatarPath
        placeholderText: '~/.face'
        buttonIcon: "photo"
        buttonTooltip: I18n.tr("panels.general.profile-tooltip")
        onButtonClicked: facePicker.openFilePicker()
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  // Fonts — RYOKU WIRED: GlobalConfig.appearance.font.family.sans / .mono
  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NSearchableComboBox {
      label: I18n.tr("panels.general.fonts-default-label")
      description: I18n.tr("panels.general.fonts-default-description")
      model: fontModel
      currentKey: GlobalConfig.appearance.font.family.sans
      placeholder: I18n.tr("panels.general.fonts-default-placeholder")
      searchPlaceholder: I18n.tr("panels.general.fonts-default-search-placeholder")
      popupHeight: 420
      onSelected: key => {
        GlobalConfig.appearance.font.family.sans = key;
        GlobalConfig.save();
      }
    }

    NSearchableComboBox {
      label: I18n.tr("panels.general.fonts-monospace-label")
      description: I18n.tr("panels.general.fonts-monospace-description")
      model: fontModel
      currentKey: GlobalConfig.appearance.font.family.mono
      placeholder: I18n.tr("panels.general.fonts-monospace-placeholder")
      searchPlaceholder: I18n.tr("panels.general.fonts-monospace-search-placeholder")
      popupHeight: 320
      onSelected: key => {
        GlobalConfig.appearance.font.family.mono = key;
        GlobalConfig.save();
      }
    }

    // Per-font scales: ryoku has a single global font size (User Interface >
    // Appearance > Font size = GlobalConfig.appearance.font.size.scale), not
    // independent sans/mono scales — greyed to avoid a non-functional duplicate.
    ColumnLayout {
      spacing: Style.marginL
      Layout.fillWidth: true
      enabled: false
      opacity: 0.45

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.general.fonts-default-scale-label")
        description: I18n.tr("panels.general.fonts-default-scale-description")
        from: 0.75
        to: 1.25
        stepSize: 0.01
        value: 1.0
        text: "100%"
      }

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.general.fonts-monospace-scale-label")
        description: I18n.tr("panels.general.fonts-monospace-scale-description")
        from: 0.75
        to: 1.25
        stepSize: 0.01
        value: 1.0
        text: "100%"
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NToggle {
    // TODO: no reverseScroll config in ryoku
    Layout.fillWidth: true
    label: I18n.tr("panels.general.reverse-scrolling-label")
    description: I18n.tr("panels.general.reverse-scrolling-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  NToggle {
    // TODO: no smoothScroll config in ryoku
    Layout.fillWidth: true
    label: I18n.tr("panels.general.smooth-scrolling-label")
    description: I18n.tr("panels.general.smooth-scrolling-description")
    checked: true
    enabled: false
    opacity: 0.45
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  RowLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NButton {
      // RYOKU: setup wizard intentionally greyed — coming in a future release.
      icon: "wand"
      text: I18n.tr("panels.general.launch-setup-wizard")
      outlined: true
      Layout.fillWidth: true
      enabled: false
      opacity: 0.45
    }

    NButton {
      icon: "external-link"
      text: I18n.tr("common.documentation")
      outlined: true
      Layout.fillWidth: true
      onClicked: Qt.openUrlExternally("https://ryoku.mintlify.app")
    }
  }
}
