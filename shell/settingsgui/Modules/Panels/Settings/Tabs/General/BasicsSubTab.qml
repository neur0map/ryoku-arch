import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.System
import qs.settingsgui.Widgets
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

  NFilePicker {
    id: obsidianVaultPicker
    title: "Select Obsidian vault"
    selectionMode: "folders"
    initialPath: GlobalConfig.paths.obsidianVaultDir || root.homeDir + "/Documents"
    onAccepted: paths => {
      if (paths.length > 0) {
        GlobalConfig.paths.obsidianVaultDir = paths[0];
        GlobalConfig.save();
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
      cache: false // avatar changes at runtime (~/.face); reload from disk, not cache
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

  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NLabel {
      label: "Obsidian notes"
      description: "Default vault and markdown note paths for the calendar popup"
      Layout.fillWidth: true
    }

    NTextInputButton {
      label: "Vault folder"
      description: "Leave empty to use Obsidian's active registered vault"
      text: GlobalConfig.paths.obsidianVaultDir
      placeholderText: "Auto-detect"
      buttonIcon: "folder-open"
      buttonTooltip: "Select vault folder"
      Layout.fillWidth: true
      onButtonClicked: obsidianVaultPicker.openFilePicker()
      onInputEditingFinished: {
        GlobalConfig.paths.obsidianVaultDir = text.trim();
        GlobalConfig.save();
      }
    }

    NTextInput {
      label: "Daily notes folder"
      description: "Folder inside the vault for dated notes"
      text: GlobalConfig.paths.obsidianDailyDir || "Daily"
      placeholderText: "Daily"
      Layout.fillWidth: true
      onEditingFinished: {
        GlobalConfig.paths.obsidianDailyDir = text.trim();
        GlobalConfig.save();
      }
    }

    NTextInput {
      label: "Quick note inbox"
      description: "Fallback markdown file for undated quick notes"
      text: GlobalConfig.paths.obsidianInboxFile || "Inbox.md"
      placeholderText: "Inbox.md"
      Layout.fillWidth: true
      onEditingFinished: {
        GlobalConfig.paths.obsidianInboxFile = text.trim();
        GlobalConfig.save();
      }
    }

    NTextInput {
      label: "Vault name"
      description: "Optional; path-based opening is used when this is empty"
      text: GlobalConfig.paths.obsidianVaultName
      placeholderText: "Optional"
      Layout.fillWidth: true
      onEditingFinished: {
        GlobalConfig.paths.obsidianVaultName = text.trim();
        GlobalConfig.save();
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

    // RYOKU: no per-font (sans / mono) size sliders here — ryoku uses a single
    // global font size (User Interface > Appearance > Font size =
    // GlobalConfig.appearance.font.size.scale). Separate scales would be a
    // non-functional duplicate of that control, so they are intentionally omitted.
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NToggle {
    // RYOKU WIRED: GlobalConfig.general.reverseScroll — reverses the bar scroll
    // actions (workspace / volume / brightness); see shell/modules/bar/Bar.qml.
    Layout.fillWidth: true
    label: I18n.tr("panels.general.reverse-scrolling-label")
    description: I18n.tr("panels.general.reverse-scrolling-description")
    checked: GlobalConfig.general.reverseScroll
    onToggled: checked => {
      GlobalConfig.general.reverseScroll = checked;
      GlobalConfig.save();
    }
  }

  NToggle {
    // RYOKU WIRED: GlobalConfig.general.smoothScrollEnabled — ryoku's
    // scroll widgets (NScrollView / NListView / NGridView) animate wheel scrolling when
    // on. Affects the panels built from those widgets (e.g. the Settings panel lists).
    Layout.fillWidth: true
    label: I18n.tr("panels.general.smooth-scrolling-label")
    description: I18n.tr("panels.general.smooth-scrolling-description")
    checked: GlobalConfig.general.smoothScrollEnabled
    onToggled: checked => {
      GlobalConfig.general.smoothScrollEnabled = checked;
      GlobalConfig.save();
    }
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
