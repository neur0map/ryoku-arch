import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallhaven search/download logic. Loaded once per host process as the plugin's
 * `main` entry point and kept alive while content opens and closes, so results
 * and paging survive. The content view (content/Widget.qml) reads this through
 * pluginApi.mainInstance.
 *
 * Host-agnostic: it never imports pill internals. Setting a wallpaper goes
 * through the shell daemon (`ryoku-shell wallpaper set <path>`), so the plugin
 * works identically from a frame popout, a desktop tile, or a window.
 */
Item {
    id: root

    property var pluginApi
    readonly property bool ready: !!(pluginApi && pluginApi.pluginDir && pluginApi.pluginDir.length > 0)

    // The host wires pluginApi after this service loads, so the command path is
    // empty until then. Run the first search as soon as the dir is known, so the
    // grid populates without any cross-component timing race.
    onReadyChanged: if (ready && results.length === 0 && !searching) searchLatest("");

    function cmdPath() { return (pluginApi ? pluginApi.pluginDir : "") + "/bin/ryoku-wallhaven-search"; }
    readonly property string apiKey: (pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings.apiKey : "") || ""
    // Prefix that injects the optional API key without replacing the process
    // environment (setting Process.environment to a dict clears PATH, so curl/jq
    // vanish). Empty when no key, so the command runs with the inherited env.
    readonly property var keyPrefix: apiKey.length > 0 ? ["env", "WALLHAVEN_API_KEY=" + apiKey] : []

    property bool searching
    property bool downloading
    property string query
    property string topRange
    property bool resultsExpanded
    property int page: 1
    property var results: []
    property string error
    property string status: ""
    property string lastDownloadedPath

    property string _searchStdout
    property string _searchStderr
    property var _pendingSearch: null
    property string _downloadStdout
    property string _downloadStderr
    property var _downloadItem: null
    property bool _downloadShouldApply

    function search(searchQuery, searchPage, range) {
        const trimmed = (searchQuery || "").trim();
        const nextPage = Math.max(1, searchPage || 1);
        const nextTopRange = range || "";

        // Not wired yet: the onReadyChanged handler will run the first search.
        if (!ready)
            return;

        resultsExpanded = true;

        if (searchProcess.running) {
            _pendingSearch = { query: trimmed, page: nextPage, topRange: nextTopRange };
            return;
        }

        query = trimmed;
        topRange = nextTopRange;
        page = nextPage;
        error = "";
        searching = true;
        _searchStdout = "";
        _searchStderr = "";
        const command = keyPrefix.concat([cmdPath(), "search", "--query", trimmed, "--page", `${nextPage}`, "--json"]);
        if (topRange.length > 0)
            command.push("--top-range", topRange);
        searchProcess.command = command;
        searchProcess.running = true;
    }

    function searchLatest(searchQuery) { search(searchQuery, 1, ""); }
    function searchTop(range) { search(query, 1, range); }
    function nextPage() { if (!searching) search(query, page + 1, topRange); }
    function previousPage() { if (page > 1 && !searching) search(query, page - 1, topRange); }
    function openInWeb(item) { if (item && item.wallhaven_url) Qt.openUrlExternally(item.wallhaven_url); }
    function download(item) { _startDownload(item, false); }
    function setAsWallpaper(item) { _startDownload(item, true); }

    function _startDownload(item, shouldApply) {
        if (!item || !item.id || !item.path)
            return;
        if (downloadProcess.running) {
            status = qsTr("A download is already running");
            return;
        }
        downloading = true;
        status = qsTr("Downloading");
        _downloadStdout = "";
        _downloadStderr = "";
        _downloadItem = item;
        _downloadShouldApply = shouldApply;
        downloadProcess.command = keyPrefix.concat([cmdPath(), "download", item.id, item.path]);
        downloadProcess.running = true;
    }

    function _finishSearch(exitCode) {
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

    function _runPendingSearch() {
        if (!_pendingSearch)
            return;
        const next = _pendingSearch;
        _pendingSearch = null;
        Qt.callLater(() => search(next.query, next.page, next.topRange));
    }

    function _finishDownload(exitCode) {
        downloading = false;
        const localPath = _downloadStdout.split("\n").filter(line => line.trim().length > 0).pop() || "";
        if (exitCode !== 0 || localPath.length === 0) {
            status = _downloadStderr.trim() || qsTr("Download failed");
            error = status;
            _downloadItem = null;
            _downloadShouldApply = false;
            return;
        }
        lastDownloadedPath = localPath;
        if (_downloadShouldApply) {
            applyProcess.command = ["ryoku-shell", "wallpaper", "set", localPath];
            applyProcess.running = true;
            status = qsTr("Wallpaper set");
        } else {
            status = qsTr("Downloaded");
        }
        _downloadItem = null;
        _downloadShouldApply = false;
    }

    Process {
        id: searchProcess
        stdout: StdioCollector { onStreamFinished: root._searchStdout = text }
        stderr: StdioCollector { onStreamFinished: root._searchStderr = text }
        onExited: exitCode => root._finishSearch(exitCode)
    }

    Process {
        id: downloadProcess
        stdout: StdioCollector { onStreamFinished: root._downloadStdout = text }
        stderr: StdioCollector { onStreamFinished: root._downloadStderr = text }
        onExited: exitCode => root._finishDownload(exitCode)
    }

    Process { id: applyProcess }
}
