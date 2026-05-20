pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
  id: root

  required property ShellScreen screen

  readonly property string screenName: screen?.name ?? ""
  readonly property var outputWorkspaces: {
    if (!CompositorService.isNiri)
      return []
    const all = NiriService.allWorkspaces ?? []
    const matched = all.filter(workspace => workspace.output === root.screenName)
    return matched.length > 0 ? matched : (NiriService.currentOutputWorkspaces ?? [])
  }
  readonly property int configuredCount: Math.max(1, Config.options?.barFrameLab?.workspaceCount ?? 8)
  readonly property int slotCount: CompositorService.isNiri ? Math.max(outputWorkspaces.length, 1) : configuredCount
  readonly property color accentColor: Config.options?.barFrameLab?.accentColor ?? Appearance.colors.colAccent
  readonly property color textColor: Config.options?.barFrameLab?.textColor ?? Appearance.colors.colOnLayer0

  spacing: 6

  function niriWorkspaceForSlot(slot: int): var {
    const index = slot - 1
    if (index < 0 || index >= outputWorkspaces.length)
      return null
    return outputWorkspaces[index] ?? null
  }

  function workspaceNumberForSlot(slot: int): int {
    if (CompositorService.isNiri)
      return niriWorkspaceForSlot(slot)?.idx ?? slot
    return slot
  }

  function isActiveSlot(slot: int): bool {
    if (CompositorService.isNiri)
      return niriWorkspaceForSlot(slot)?.is_active ?? false
    if (CompositorService.isHyprland)
      return (Hyprland.focusedWorkspace?.id ?? 1) === slot
    return slot === 1
  }

  function isOccupiedSlot(slot: int): bool {
    if (CompositorService.isNiri) {
      const workspace = niriWorkspaceForSlot(slot)
      if (!workspace)
        return false
      return (NiriService.windows ?? []).some(window => window.workspace_id === workspace.id)
    }
    if (CompositorService.isHyprland)
      return Hyprland.workspaces.values.some(workspace => workspace.id === slot)
    return false
  }

  function switchToSlot(slot: int): void {
    if (CompositorService.isNiri) {
      NiriService.switchToWorkspace(workspaceNumberForSlot(slot))
      return
    }
    if (CompositorService.isHyprland)
      Hyprland.dispatch(`workspace ${slot}`)
  }

  Repeater {
    model: root.slotCount

    delegate: MouseArea {
      id: workspaceButton

      required property int index
      readonly property int slot: index + 1
      readonly property bool active: root.isActiveSlot(slot)
      readonly property bool occupied: root.isOccupiedSlot(slot)

      Layout.alignment: Qt.AlignHCenter
      implicitWidth: 32
      implicitHeight: 32
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.switchToSlot(slot)

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: workspaceButton.active
          ? root.accentColor
          : workspaceButton.containsMouse
            ? ColorUtils.transparentize(root.accentColor, 0.78)
            : "transparent"
        border.width: workspaceButton.active ? 0 : 1
        border.color: workspaceButton.occupied
          ? ColorUtils.transparentize(root.accentColor, 0.22)
          : ColorUtils.transparentize(root.textColor, 0.72)
      }

      StyledText {
        anchors.centerIn: parent
        text: String(root.workspaceNumberForSlot(workspaceButton.slot)).padStart(2, "0")
        color: workspaceButton.active ? Appearance.colors.colLayer0 : root.textColor
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
      }
    }
  }
}
