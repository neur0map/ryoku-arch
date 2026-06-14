pragma Singleton

import QtQuick
import Ryoku.Config
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Modules.Tooltip

Singleton {
  id: root

  property var activeTooltip: null
  property var pendingTooltip: null

  property Component tooltipComponent: Component {
    Tooltip {}
  }

  function show(target, content, direction, delay, fontFamily) {
    if (!GlobalConfig.ui.tooltipsEnabled) {
      return;
    }

    if (!target || !content || (Array.isArray(content) && content.length === 0)) {
      Logger.i("Tooltip", "No target or content");
      return;
    }

    if (pendingTooltip) {
      pendingTooltip.hideImmediately();
      pendingTooltip.destroy();
      pendingTooltip = null;
    }

    if (activeTooltip && activeTooltip.targetItem !== target) {
      activeTooltip.hideImmediately();
      // Don't destroy immediately - let it clean itself up
      activeTooltip = null;
    }

    if (activeTooltip && activeTooltip.targetItem === target) {
      activeTooltip.updateContent(content);
      return activeTooltip;
    }

    const newTooltip = tooltipComponent.createObject(null);

    if (newTooltip) {
      pendingTooltip = newTooltip;

      newTooltip.visibleChanged.connect(() => {
                                          if (!newTooltip.visible) {
                                            // Clean up after a delay to avoid interfering with new tooltips
                                            Qt.callLater(() => {
                                                           if (newTooltip && !newTooltip.visible) {
                                                             if (activeTooltip === newTooltip) {
                                                               activeTooltip = null;
                                                             }
                                                             if (pendingTooltip === newTooltip) {
                                                               pendingTooltip = null;
                                                             }
                                                             newTooltip.destroy();
                                                           }
                                                         });
                                          } else {
                                            if (pendingTooltip === newTooltip) {
                                              activeTooltip = newTooltip;
                                              pendingTooltip = null;
                                            }
                                          }
                                        });

      newTooltip.show(target, content, direction || "auto", delay || Style.tooltipDelay, fontFamily);

      return newTooltip;
    } else {
      Logger.e("Tooltip", "Failed to create tooltip instance");
    }

    return null;
  }

  function hide(target) {
    if (target) {
      if (pendingTooltip && pendingTooltip.targetItem === target) {
        pendingTooltip.hide();
      }
      if (activeTooltip && activeTooltip.targetItem === target) {
        activeTooltip.hide();
      }
    } else {
      if (pendingTooltip) {
        pendingTooltip.hide();
      }
      if (activeTooltip) {
        activeTooltip.hide();
      }
    }
  }

  function hideImmediately() {
    if (pendingTooltip) {
      pendingTooltip.hideImmediately();
      pendingTooltip.destroy();
      pendingTooltip = null;
    }
    if (activeTooltip) {
      activeTooltip.hideImmediately();
      activeTooltip.destroy();
      activeTooltip = null;
    }
  }

  function updateContent(newContent) {
    if (activeTooltip) {
      activeTooltip.updateContent(newContent);
    }
  }

  // Backward compatibility alias
  function updateText(newText) {
    updateContent(newText);
  }
}
