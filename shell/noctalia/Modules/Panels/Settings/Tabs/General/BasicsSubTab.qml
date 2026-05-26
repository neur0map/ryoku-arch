import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.System
import qs.noctalia.Widgets

ColumnLayout {
  id: root

  // Profile section
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginL
    enabled: false
    opacity: 0.45

    NImageRounded {
      // TODO: wire avatar image to ryoku (no avatarImage config in ryoku)
      Layout.preferredWidth: 128 * Style.uiScaleRatio
      Layout.preferredHeight: width
      radius: width / 2
      imagePath: ""
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
        // TODO: wire avatar image path to ryoku (no avatarImage config in ryoku)
        label: I18n.tr("panels.general.profile-picture-label")
        description: I18n.tr("panels.general.profile-picture-description")
        text: ""
        placeholderText: '~/.face'
        buttonIcon: "photo"
        buttonTooltip: I18n.tr("panels.general.profile-tooltip")
        onInputTextChanged: text => {}
        onButtonClicked: {}
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  // Fonts
  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true
    enabled: false
    opacity: 0.45

    NSearchableComboBox {
      // TODO: wire default font to ryoku (no fontDefault config in ryoku; FontService not available)
      label: I18n.tr("panels.general.fonts-default-label")
      description: I18n.tr("panels.general.fonts-default-description")
      model: []
      currentKey: ""
      placeholder: I18n.tr("panels.general.fonts-default-placeholder")
      searchPlaceholder: I18n.tr("panels.general.fonts-default-search-placeholder")
      popupHeight: 420
    }

    NSearchableComboBox {
      // TODO: wire monospace font to ryoku (no fontFixed config in ryoku; FontService not available)
      label: I18n.tr("panels.general.fonts-monospace-label")
      description: I18n.tr("panels.general.fonts-monospace-description")
      model: []
      currentKey: ""
      placeholder: I18n.tr("panels.general.fonts-monospace-placeholder")
      searchPlaceholder: I18n.tr("panels.general.fonts-monospace-search-placeholder")
      popupHeight: 320
    }

    NValueSlider {
      // TODO: wire default font scale to ryoku (no fontDefaultScale config in ryoku)
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
      // TODO: wire monospace font scale to ryoku (no fontFixedScale config in ryoku)
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

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NToggle {
    // TODO: wire reverse scroll to ryoku (no reverseScroll config in ryoku)
    Layout.fillWidth: true
    label: I18n.tr("panels.general.reverse-scrolling-label")
    description: I18n.tr("panels.general.reverse-scrolling-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  NToggle {
    // TODO: wire smooth scrolling to ryoku (no smoothScrollEnabled config in ryoku)
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
      // TODO: wire setup wizard to ryoku (no setupWizardPanel in ryoku PanelService)
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
      onClicked: {
        Qt.openUrlExternally("https://ryoku.mintlify.app");
      }
    }
  }
}
