import QtQuick
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Widgets

// Settings > Display > GPU: pick which GPU renders the desktop on multi-GPU machines
// (the strongest discrete/eGPU should drive the desktop so streaming and screen sharing
// run on it instead of a weak iGPU). Backed by GpuService -> ryoku-gpu.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  Component.onCompleted: GpuService.refresh()

  NHeader {
    label: I18n.tr("panels.display.gpu-title")
    description: I18n.tr("panels.display.gpu-description")
  }

  // The render-device pin is Hyprland-only.
  NText {
    visible: !GpuService.supported
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: I18n.tr("panels.display.gpu-unsupported")
    color: Color.mOnSurfaceVariant
  }

  // Detected GPUs (informational), strongest first.
  Repeater {
    model: GpuService.supported ? GpuService.gpus : []

    NBox {
      id: card
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: gpuRow.implicitHeight + Style.margin2L

      RowLayout {
        id: gpuRow
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            Layout.fillWidth: true
            text: (card.modelData.model && card.modelData.model.length > 0) ? card.modelData.model : (card.modelData.driver + " (" + card.modelData.card + ")")
            font.weight: Style.fontWeightBold
          }
          NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            text: {
              var bits = [I18n.tr("panels.display.gpu-class-" + card.modelData["class"])];
              if (card.modelData.vramMb && card.modelData.vramMb > 0)
                bits.push(Math.round(card.modelData.vramMb / 1024) + " GB");
              if (card.modelData.connected)
                bits.push(I18n.tr("panels.display.gpu-display-attached"));
              return bits.join("  •  ");
            }
          }
        }

        // Badge on the currently pinned primary GPU.
        NText {
          visible: GpuService.configured && GpuService.pinned === card.modelData.slot
          text: I18n.tr("panels.display.gpu-primary-badge")
          color: Color.mPrimary
          font.weight: Style.fontWeightBold
        }
      }
    }
  }

  // Single-GPU machines have nothing to switch.
  NText {
    visible: GpuService.supported && GpuService.ngpu < 2
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: I18n.tr("panels.display.gpu-single")
    color: Color.mOnSurfaceVariant
  }

  // Picker (meaningful only with 2+ GPUs). "Automatic" follows the battery-aware policy
  // (strongest on desktop/eGPU, iGPU on a hybrid laptop); a specific GPU forces it.
  NComboBox {
    visible: GpuService.supported && GpuService.ngpu >= 2
    Layout.fillWidth: true
    label: I18n.tr("panels.display.gpu-primary-label")
    description: I18n.tr("panels.display.gpu-primary-description")
    model: GpuService.choices
    currentKey: GpuService.selectedKey
    onSelected: key => GpuService.select(key)
  }

  // AQ_DRM_DEVICES is read at compositor start, so a change needs a re-login.
  NText {
    visible: GpuService.supported && GpuService.ngpu >= 2
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: GpuService.pendingRelogin ? Color.mPrimary : Color.mOnSurfaceVariant
    text: GpuService.pendingRelogin ? I18n.tr("panels.display.gpu-relogin-now") : I18n.tr("panels.display.gpu-relogin-hint")
  }
}
