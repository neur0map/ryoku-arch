pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
  id: root

  readonly property string commandName: "ryoku-wallhaven-search"

  property bool searching
  property bool downloading
  property string query
  property string topRange
  property bool resultsExpanded
  property int page: 1
  property var results: []
  property string error
  property string lastDownloadedPath

  property string _searchStdout
  property string _searchStderr
  property var _pendingSearch: null
  property string _downloadStdout
  property string _downloadStderr
  property var _downloadItem: null
  property bool _downloadShouldApply

  function search(searchQuery: string, searchPage: int, range: string): void {
    const trimmed = (searchQuery || "").trim();
    const nextPage = Math.max(1, searchPage || 1);
    const nextTopRange = range || "";

    if (trimmed.length === 0 && nextTopRange.length === 0) {
      query = "";
      topRange = "";
      resultsExpanded = false;
      page = 1;
      error = "";
      results = [];
      return;
    }

    resultsExpanded = true;

    if (searchProcess.running) {
      _pendingSearch = {
        query: trimmed,
        page: nextPage,
        topRange: nextTopRange
      };
      return;
    }

    query = trimmed;
    topRange = nextTopRange;
    page = nextPage;
    error = "";
    searching = true;
    _searchStdout = "";
    _searchStderr = "";
    const command = [commandName, "search", "--query", trimmed, "--page", `${nextPage}`, "--json"];
    if (topRange.length > 0)
      command.push("--top-range", topRange);
    searchProcess.command = command;
    searchProcess.running = true;
  }

  function searchLatest(searchQuery: string): void {
    search(searchQuery, 1, "");
  }

  function searchTop(range: string): void {
    search(query, 1, range);
  }

  function nextPage(): void {
    if ((query.length > 0 || topRange.length > 0) && !searching)
      search(query, page + 1, topRange);
  }

  function previousPage(): void {
    if ((query.length > 0 || topRange.length > 0) && page > 1 && !searching)
      search(query, page - 1, topRange);
  }

  function openInWeb(item: var): void {
    if (item && item.wallhaven_url)
      Qt.openUrlExternally(item.wallhaven_url);
  }

  function download(item: var): void {
    _startDownload(item, false);
  }

  function setAsWallpaper(item: var): void {
    _startDownload(item, true);
  }

  function _startDownload(item: var, shouldApply: bool): void {
    if (!item || !item.id || !item.path)
      return;

    if (downloadProcess.running) {
      Toaster.toast(qsTr("Wallhaven"), qsTr("A wallpaper download is already running"), "download");
      return;
    }

    downloading = true;
    _downloadStdout = "";
    _downloadStderr = "";
    _downloadItem = item;
    _downloadShouldApply = shouldApply;
    downloadProcess.command = [commandName, "download", item.id, item.path];
    downloadProcess.running = true;
  }

  function _finishSearch(exitCode: int): void {
    searching = false;

    if (exitCode !== 0) {
      error = _searchStderr.trim() || qsTr("Wallhaven search failed");
      results = [];
      _runPendingSearch();
      return;
    }

    const rows = [];
    const lines = _searchStdout.split("\n").filter(line => line.trim().length > 0);
    try {
      for (const line of lines)
        rows.push(JSON.parse(line));
      results = rows;
      error = "";
    } catch (e) {
      error = qsTr("Failed to parse Wallhaven results");
      results = [];
    }

    _runPendingSearch();
  }

  function _runPendingSearch(): void {
    if (!_pendingSearch)
      return;

    const next = _pendingSearch;
    _pendingSearch = null;
    Qt.callLater(() => search(next.query, next.page, next.topRange));
  }

  function _finishDownload(exitCode: int): void {
    downloading = false;

    const localPath = _downloadStdout.split("\n").filter(line => line.trim().length > 0).pop() || "";
    if (exitCode !== 0 || localPath.length === 0) {
      Toaster.toast(qsTr("Wallhaven"), _downloadStderr.trim() || qsTr("Download failed"), "error");
      _downloadItem = null;
      _downloadShouldApply = false;
      return;
    }

    lastDownloadedPath = localPath;
    if (_downloadShouldApply) {
      Wallpapers.setWallpaper(localPath);
      Toaster.toast(qsTr("Wallpaper set"), localPath, "wallpaper");
    } else {
      Toaster.toast(qsTr("Wallpaper downloaded"), localPath, "download_done");
    }

    _downloadItem = null;
    _downloadShouldApply = false;
  }

  Process {
    id: searchProcess

    stdout: StdioCollector {
      onStreamFinished: root._searchStdout = text
    }

    stderr: StdioCollector {
      onStreamFinished: root._searchStderr = text
    }

    onExited: exitCode => root._finishSearch(exitCode)
  }

  Process {
    id: downloadProcess

    stdout: StdioCollector {
      onStreamFinished: root._downloadStdout = text
    }

    stderr: StdioCollector {
      onStreamFinished: root._downloadStderr = text
    }

    onExited: exitCode => root._finishDownload(exitCode)
  }
}
