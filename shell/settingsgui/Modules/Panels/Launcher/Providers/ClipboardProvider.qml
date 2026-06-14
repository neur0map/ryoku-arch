import QtQuick
import Ryoku.Config
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Keyboard
import qs.settingsgui.Services.Platform

Item {
  id: root

  property string name: I18n.tr("launcher.providers.clipboard")
  property var launcher: null
  property string iconMode: GlobalConfig.launcher.iconMode
  property string supportedLayouts: "list"
  property bool wrapNavigation: false // Don't wrap at end of list

  property bool handleSearch: false

  property bool hasPreview: GlobalConfig.launcher.enableClipPreview
  property string previewComponentPath: "./ClipboardPreview.qml"

  // Image handling - expose revision for reactive updates in delegates
  readonly property int imageRevision: ClipboardService.revision

  property var availableCategories: GlobalConfig.launcher.enableClipboardChips ? ["All", "Images", "Links", "Files", "Code", "Colors"] : []
  property string selectedCategory: "All"

  function selectCategory(cat) {
    if (selectedCategory !== cat) {
      selectedCategory = cat;
      if (launcher) {
        launcher.updateResults();
      }
    }
  }

  property var categoryIcons: {
    "All": iconMode === "tabler" ? "border-all" : "view-grid",
    "Images": iconMode === "tabler" ? "photo" : "image",
    "Links": iconMode === "tabler" ? "link" : "insert-link",
    "Files": iconMode === "tabler" ? "file" : "text-x-generic",
    "Code": iconMode === "tabler" ? "code" : "text-x-script",
    "Colors": iconMode === "tabler" ? "palette" : "color-picker"
  }

  property bool isWaitingForData: false
  property bool gotResults: false
  property string lastSearchText: ""

  Connections {
    target: ClipboardService
    function onListCompleted() {
      if (gotResults && (lastSearchText === searchText)) {
        // Do not update results after the first fetch.
        // This will avoid the list resetting every 2seconds when the service updates.
        return;
      }
      // Refresh results if we're waiting for data or if clipboard plugin is active
      if (isWaitingForData || (launcher && launcher.searchText.startsWith(">clip"))) {
        isWaitingForData = false;
        gotResults = true;
        if (launcher) {
          launcher.updateResults();
        }
      }
    }
    function onActiveChanged() {
      // When active state changes (e.g. dependency check completes), refresh results
      if (ClipboardService.active && launcher && launcher.searchText.startsWith(">clip")) {
        isWaitingForData = true;
        gotResults = false;
        ClipboardService.list(100);
      }
    }
  }

  function init() {
    Logger.d("ClipboardProvider", "Initialized");
    // Pre-load clipboard data if service is active
    if (ClipboardService.active) {
      ClipboardService.list(100);
    }
  }

  function onOpened() {
    isWaitingForData = true;
    gotResults = false;
    lastSearchText = "";

    if (ClipboardService.active) {
      ClipboardService.list(100);
    }
  }

  function handleCommand(searchText) {
    return searchText.startsWith(">clip");
  }

  // Return available commands when user types ">"
  function commands() {
    return [
          {
            "name": ">clip",
            "description": I18n.tr("launcher.providers.clipboard-search-description"),
            "icon": iconMode === "tabler" ? "clipboard" : "diodon",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function () {
              launcher.setSearchText(">clip ");
            }
          },
          {
            "name": ">clip clear",
            "description": I18n.tr("launcher.providers.clipboard-clear-description"),
            "icon": iconMode === "tabler" ? "trash" : "user-trash",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function () {
              ClipboardService.wipeAll();
              launcher.close();
            }
          }
        ];
  }

  function getResults(searchText) {
    if (!searchText.startsWith(">clip")) {
      return [];
    }

    lastSearchText = searchText;
    const results = [];
    const query = searchText.slice(5).trim();

    if (!ClipboardService.active) {
      // If dependency check hasn't completed yet, show loading instead of disabled
      if (!ClipboardService.dependencyChecked) {
        return [
              {
                "name": I18n.tr("launcher.providers.clipboard-loading"),
                "description": I18n.tr("launcher.providers.emoji-loading-description"),
                "icon": iconMode === "tabler" ? "refresh" : "view-refresh",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function () {}
              }
            ];
      }
      return [
            {
              "name": I18n.tr("launcher.providers.clipboard-history-disabled"),
              "description": I18n.tr("launcher.providers.clipboard-history-disabled-description"),
              "icon": iconMode === "tabler" ? "refresh" : "view-refresh",
              "isTablerIcon": true,
              "isImage": false,
              "onActivate": function () {}
            }
          ];
    }

    // Special command: clear
    if (query === "clear") {
      return [
            {
              "name": I18n.tr("launcher.providers.clipboard-clear-history"),
              "description": I18n.tr("launcher.providers.clipboard-clear-description-full"),
              "icon": iconMode === "tabler" ? "trash" : "user-trash",
              "isTablerIcon": true,
              "isImage": false,
              "onActivate": function () {
                ClipboardService.wipeAll();
                launcher.close();
              }
            }
          ];
    }

    if (ClipboardService.loading || isWaitingForData) {
      return [
            {
              "name": I18n.tr("launcher.providers.clipboard-loading"),
              "description": I18n.tr("launcher.providers.emoji-loading-description"),
              "icon": iconMode === "tabler" ? "refresh" : "view-refresh",
              "isTablerIcon": true,
              "isImage": false,
              "onActivate": function () {}
            }
          ];
    }

    const items = ClipboardService.items || [];

    // If no items and we haven't tried loading yet, trigger a load
    if (items.count === 0 && !ClipboardService.loading) {
      isWaitingForData = true;
      ClipboardService.list(100);
      return [
            {
              "name": I18n.tr("launcher.providers.clipboard-loading"),
              "description": I18n.tr("launcher.providers.emoji-loading-description"),
              "icon": iconMode === "tabler" ? "refresh" : "view-refresh",
              "isTablerIcon": true,
              "isImage": false,
              "onActivate": function () {}
            }
          ];
    }

    const searchTerm = query.toLowerCase();

    const now = Date.now() / 1000;

    const catMap = {
      "Images": "image",
      "Links": "link",
      "Files": "file",
      "Code": "code",
      "Colors": "color"
    };

    items.forEach(function (item) {
      if (GlobalConfig.launcher.enableClipboardChips && root.selectedCategory !== "All") {
        if (item.contentType !== catMap[root.selectedCategory]) {
          return;
        }
      }

      const preview = (item.preview || "").toLowerCase();

      if (searchTerm && preview.indexOf(searchTerm) === -1) {
        return;
      }

      const firstSeen = ClipboardService.firstSeenById[item.id] || now;

      let entry;
      if (item.isImage) {
        entry = formatImageEntry(item, firstSeen);
      } else {
        entry = formatTextEntry(item, firstSeen);
      }

      entry.onActivate = function () {
        if (GlobalConfig.launcher.autoPasteClipboard) {
          launcher.closeImmediately();
          Qt.callLater(() => {
                         ClipboardService.pasteFromClipboard(item.id, item.mime);
                       });
        } else {
          ClipboardService.copyToClipboard(item.id);
          launcher.close();
        }
      };

      results.push(entry);
    });

    if (results.length === 0) {
      results.push({
                     "name": searchTerm ? "No matching clipboard items" : "Clipboard is empty",
                     "description": searchTerm ? `No items containing "${query}"` : "Copy something to see it here",
                     "icon": iconMode === "tabler" ? "clipboard" : "text-x-generic",
                     "isTablerIcon": true,
                     "isImage": false,
                     "onActivate": function () {
                     }
                   });
    }

    //Logger.i("ClipboardPlugin", `Returning ${results.length} results for query: "${query}"`)
    return results;
  }

  function formatImageEntry(item, firstSeen) {
    const meta = ClipboardService.parseImageMeta(item.preview);
    const timeStr = Time.formatRelativeTime(new Date(firstSeen * 1000));
    let desc = meta ? `${meta.fmt} • ${meta.size}` : item.mime || "Image data";
    if (timeStr)
      desc += ` • ${timeStr}`;

    return {
      "name": meta ? `Image ${meta.w}×${meta.h}` : "Image",
      "description": desc,
      "icon": iconMode === "tabler" ? "photo" : "image",
      "isTablerIcon": true,
      "isImage": true,
      "imageWidth": meta ? meta.w : 0,
      "imageHeight": meta ? meta.h : 0,
      "clipboardId": item.id,
      "mime": item.mime,
      "preview": item.preview,
      "provider": root
    };
  }

  function formatTextEntry(item, firstSeen) {
    const preview = (item.preview || "").trim();
    const lines = preview.split('\n').filter(l => l.trim());

    let title = lines[0] || "Empty text";
    if (title.length > 60) {
      title = title.substring(0, 57) + "...";
    }

    let description = "";
    if (lines.length > 1) {
      description = lines[1];
      if (description.length > 80) {
        description = description.substring(0, 77) + "...";
      }
    } else {
      // Preview is truncated at ~100 chars, so we can't show exact count
      if (preview.length >= 100) {
        description = I18n.tr("toast.clipboard.long-text");
      } else {
        const chars = preview.length;
        const words = preview.split(/\s+/).length;
        description = `${chars} characters, ${words} word${words !== 1 ? 's' : ''}`;
      }
    }

    const timeStr = Time.formatRelativeTime(new Date(firstSeen * 1000));
    if (timeStr)
      description += ` • ${timeStr}`;

    let defaultIcon = iconMode === "tabler" ? "clipboard" : "text-x-generic";
    let colorHex = "";
    if (GlobalConfig.launcher.enableClipboardSmartIcons) {
      if (item.contentType === "link")
        defaultIcon = iconMode === "tabler" ? "link" : "insert-link";
      else if (item.contentType === "file")
        defaultIcon = iconMode === "tabler" ? "file" : "text-x-generic";
      else if (item.contentType === "code")
        defaultIcon = iconMode === "tabler" ? "code" : "text-x-script";
      else if (item.contentType === "color") {
        defaultIcon = iconMode === "tabler" ? "palette" : "color-picker";
        colorHex = preview;
      }
    }

    return {
      "name": title,
      "description": description,
      "icon": defaultIcon,
      "isTablerIcon": true,
      "isImage": false,
      "clipboardId": item.id,
      "preview": preview,
      "contentType": item.contentType,
      "colorHex": colorHex,
      "provider": root
    };
  }

  function getImageForItem(clipboardId) {
    return ClipboardService.getImageData ? ClipboardService.getImageData(clipboardId) : null;
  }

  function getItemActions(item) {
    if (!item || !item.clipboardId)
      return [];

    var actions = [];

    if (item.isImage && GlobalConfig.launcher.screenshotAnnotationTool.trim() !== "") {
      actions.push({
                     "icon": "pencil",
                     "tooltip": I18n.tr("tooltips.open-annotation-tool"),
                     "action": function () {
                       var tool = GlobalConfig.launcher.screenshotAnnotationTool.trim();
                       Quickshell.execDetached(["sh", "-c", "cliphist decode " + item.clipboardId + " | " + tool]);
                       if (launcher)
                         launcher.close();
                     }
                   });
    }

    actions.push({
                   "icon": "trash",
                   "tooltip": I18n.tr("launcher.providers.clipboard-delete"),
                   "action": function () {
                     deleteItem(item);
                   }
                 });

    return actions;
  }

  function canDeleteItem(item) {
    return item && !!item.clipboardId;
  }

  function deleteItem(item) {
    if (!item || !item.clipboardId)
      return;

    // Set provider state before deletion so refresh works
    gotResults = false;
    isWaitingForData = true;
    lastSearchText = launcher ? launcher.searchText : "";

    ClipboardService.deleteById(String(item.clipboardId));
  }

  // Prepare item for display (handles image decoding)
  function prepareItem(item) {
    if (item && item.isImage && item.clipboardId) {
      if (!ClipboardService.getImageData(item.clipboardId)) {
        ClipboardService.decodeToDataUrl(item.clipboardId, item.mime, null);
      }
    }
  }

  // Get image URL for item (used by delegates)
  function getImageUrl(item) {
    if (!item || !item.clipboardId)
      return "";
    return ClipboardService.getImageData(item.clipboardId) || "";
  }

  function getPreviewData(item) {
    if (!item)
      return null;
    return {
      "clipboardId": item.clipboardId,
      "isImage": item.isImage,
      "mime": item.mime,
      "preview": item.preview
    };
  }
}
