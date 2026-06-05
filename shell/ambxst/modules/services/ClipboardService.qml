pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool active: true
    property var items: []
    property var imageDataById: ({})
    property var linkPreviewCache: ({})
    property int revision: 0
    property bool _operationInProgress: false
    
    readonly property string dbPath: Quickshell.dataPath("clipboard.db")
    readonly property string binaryDataDir: Quickshell.dataPath("clipboard-data")
    readonly property string schemaPath: Qt.resolvedUrl("clipboard_init.sql").toString().replace("file://", "")
    readonly property string insertScriptPath: Qt.resolvedUrl("../../scripts/clipboard_insert.sh").toString().replace("file://", "")
    readonly property string checkScriptPath: Qt.resolvedUrl("../../scripts/clipboard_check.sh").toString().replace("file://", "")
    readonly property string watchScriptPath: Qt.resolvedUrl("../../scripts/clipboard_watch.sh").toString().replace("file://", "")
    readonly property string linkPreviewScriptPath: Qt.resolvedUrl("../../scripts/link_preview.py").toString().replace("file://", "")

    property bool _initialized: false

    property var suspendConnections: Connections {
        target: SuspendManager
        function onWakingUp() {
            // Small delay to allow wl-paste to work again after wake
            wakeRestartTimer.restart();
        }
    }

    property var wakeRestartTimer: Timer {
        id: wakeRestartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root._initialized) {
                root.list();
                clipboardWatcher.running = true;
            }
        }
    }

    signal listCompleted()

    property Process clipboardWatcher: Process {
        running: root._initialized && !SuspendManager.isSuspending
        command: [watchScriptPath, checkScriptPath, dbPath, insertScriptPath, binaryDataDir]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split('\n');
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i] === "REFRESH_LIST") {
                        Qt.callLater(root.list);
                    }
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0 && !text.includes("No selection")) {
                    console.warn("ClipboardService: watcher stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            // Watcher should keep running, restart if it exits (unless suspending)
            if (root._initialized && !SuspendManager.isSuspending) {
                console.warn("ClipboardService: watcher exited with code:", code, "- restarting...");
                Qt.callLater(function() {
                    if (root._initialized && !SuspendManager.isSuspending) {
                        clipboardWatcher.running = true;
                    }
                });
            }
        }
    }

    property Process initDbProcess: Process {
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) console.warn("ClipboardService: DB Init Error: " + text)
            }
        }

        onExited: function(code) {
            if (code === 0) {
                root._initialized = true;
                ensureBinaryDataDir();
                Qt.callLater(root.list);
            } else {
                console.warn("ClipboardService: Failed to initialize database (Exit code: " + code + ")");
            }
        }
    }

    property Process ensureDirProcess: Process {
        running: false
    }

    property Process checkAndInsertProcess: Process {
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0 && !text.includes("No selection")) {
                    console.warn("ClipboardService: checkAndInsertProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            _operationInProgress = false;
            if (code === 0) {
                Qt.callLater(root.list);
            }
        }
    }

    property Process listProcess: Process {
        running: false
        
        stdout: StdioCollector {
            waitForEnd: true
            
            onStreamFinished: {
                var clipboardItems = [];
                
                var trimmedText = text.trim();
                if (trimmedText.length === 0) {
                    root.items = clipboardItems;
                    root.listCompleted();
                    root._operationInProgress = false;
                    return;
                }
                
                try {
                    var jsonArray = JSON.parse(trimmedText);
                    
                    for (var i = 0; i < jsonArray.length; i++) {
                        var item = jsonArray[i];
                        var isFile = item.mime_type === "text/uri-list";
                        
                        var preview = item.preview;
                        if (isFile && item.full_content) {
                            var uriContent = item.full_content.trim();
                            if (uriContent.startsWith("file://")) {
                                var filePath = uriContent.substring(7);
                                var fileName = filePath.split('/').pop();
                                fileName = root.decodeUriString(fileName);
                                preview = "[File] " + fileName;
                            }
                        } else if (item.is_image === 1) {
                            preview = "[Image]";
                        }
                        
                        clipboardItems.push({
                            id: item.id.toString(),
                            preview: preview,
                            fullContent: item.preview,
                            mime: item.mime_type,
                            isImage: item.is_image === 1,
                            isFile: isFile,
                            binaryPath: item.binary_path || "",
                            hash: item.content_hash || "",
                            size: item.size || 0,
                            createdAt: item.created_at || 0,
                            pinned: item.pinned === 1,
                            alias: item.alias || "",
                            displayIndex: item.display_index !== null ? item.display_index : -1
                        });
                    }
                } catch (e) {
                    console.warn("ClipboardService: Failed to parse clipboard items:", e);
                }
                
                root.items = clipboardItems;
                root.listCompleted();
                root._operationInProgress = false;
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: listProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code !== 0) {
                root.items = [];
                root.listCompleted();
                root._operationInProgress = false;
            }
        }
    }

    property Process insertProcess: Process {
        property string itemHash: ""
        property string itemContent: ""
        property string tmpFile: ""
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: insertProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code === 0) {
                Qt.callLater(root.list);
            } else {
                console.warn("ClipboardService: insertProcess failed with code:", code);
                root._operationInProgress = false;
            }
            
            itemHash = "";
            itemContent = "";
            tmpFile = "";
        }
    }

    property Process getContentProcess: Process {
        property string itemId: ""
        running: false
        
        stdout: StdioCollector {
            waitForEnd: true
            
            onStreamFinished: {
                root.fullContentRetrieved(getContentProcess.itemId, text);
            }
        }
        
        onExited: function(code) {
            if (code !== 0) {
                root.fullContentRetrieved(getContentProcess.itemId, "");
            }
        }
    }

    property Process deleteProcess: Process {
        property string itemId: ""
        running: false
        
        stdout: StdioCollector {
            waitForEnd: true
            
            onStreamFinished: {
                var deletedHash = text.trim();
                if (deletedHash.length > 0) {
                    clearClipboardIfMatches.deletedHash = deletedHash;
                    clearClipboardIfMatches.running = true;
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: deleteProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code === 0) {
                Qt.callLater(root.list);
            } else {
                root._operationInProgress = false;
            }
        }
    }
    
    property Process clearClipboardIfMatches: Process {
        property string deletedHash: ""
        running: false
        
        command: ["sh", "-c",
            "# Get current clipboard hash for different types\n" +
            "CURRENT_HASH=''; " +
            "if CONTENT=$(wl-paste --type text/uri-list 2>/dev/null); then " +
            "  CURRENT_HASH=$(echo -n \"$CONTENT\" | tr -d '\\r' | md5sum | cut -d' ' -f1); " +
            "elif CONTENT=$(wl-paste --type text/plain 2>/dev/null); then " +
            "  CURRENT_HASH=$(echo -n \"$CONTENT\" | md5sum | cut -d' ' -f1); " +
            "elif IMAGE_MIME=$(wl-paste --list-types 2>/dev/null | grep '^image/' | head -1); then " +
            "  [ -n \"$IMAGE_MIME\" ] && CURRENT_HASH=$(wl-paste --type \"$IMAGE_MIME\" 2>/dev/null | md5sum | cut -d' ' -f1); " +
            "fi; " +
            "# Clear clipboard if hashes match\n" +
            "if [ \"$CURRENT_HASH\" = '" + deletedHash + "' ]; then " +
            "  wl-copy --clear 2>/dev/null || true; " +
            "fi"
        ]
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0 && !text.includes("No selection")) {
                    console.warn("ClipboardService: clearClipboardIfMatches stderr:", text);
                }
            }
        }
    }

    property Process clearProcess: Process {
        running: false
        
        onExited: function(code) {
            if (code === 0) {
                Qt.callLater(root.list);
                cleanBinaryDataDirProcess.running = true;
            }
        }
    }
    
    property Process togglePinProcess: Process {
        property string itemId: ""
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: togglePinProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code === 0) {
                Qt.callLater(root.list);
            } else {
                root._operationInProgress = false;
            }
        }
    }
    
    property Process setAliasProcess: Process {
        property string itemId: ""
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: setAliasProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code === 0) {
                Qt.callLater(root.list);
            } else {
                root._operationInProgress = false;
            }
        }
    }
    
    property Process cleanBinaryDataDirProcess: Process {
        running: false
        command: ["sh", "-c", 
            "cd '" + binaryDataDir + "' && " +
            "for f in *; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  sqlite3 '" + dbPath + "' \"SELECT COUNT(*) FROM clipboard_items WHERE binary_path = '" + binaryDataDir + "/$f';\" | grep -q '^0$' && rm -f \"$f\"; " +
            "done"
        ]
    }

    property Process loadImageProcess: Process {
        property string itemId: ""
        property string mimeType: ""
        running: false
        
        stdout: StdioCollector {
            waitForEnd: true
            
            onStreamFinished: {
                if (text.length > 0) {
                    var cleanBase64 = text.replace(/\s/g, '');
                    var dataUrl = "data:" + loadImageProcess.mimeType + ";base64," + cleanBase64;
                    root.imageDataById[loadImageProcess.itemId] = dataUrl;
                    root.revision++;
                }
            }
        }
    }
    
    property Process linkPreviewProcess: Process {
        property string requestUrl: ""
        property string requestItemId: ""
        running: false
        
        stdout: StdioCollector {
            waitForEnd: true
            
            onStreamFinished: {
                try {
                    var metadata = JSON.parse(text);
                    // Use request_url from the response - this is the original URL we requested
                    // This is crucial because requestUrl property may have been overwritten
                    // by a subsequent request before this response arrived
                    var responseUrl = metadata.request_url || metadata.url || linkPreviewProcess.requestUrl;
                    
                    if (!metadata.error && responseUrl) {
                        root.linkPreviewCache[responseUrl] = metadata;
                    }
                    // Note: requestItemId may also be stale, but the receiver validates it
                    root.linkPreviewFetched(responseUrl, metadata, linkPreviewProcess.requestItemId);
                } catch (e) {
                    console.warn("ClipboardService: Failed to parse link preview:", e);
                    root.linkPreviewFetched(linkPreviewProcess.requestUrl, {'error': 'Failed to parse response'}, linkPreviewProcess.requestItemId);
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: linkPreviewProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code !== 0) {
                root.linkPreviewFetched(linkPreviewProcess.requestUrl, {'error': 'Failed to fetch preview'}, linkPreviewProcess.requestItemId);
            }
        }
    }

    signal fullContentRetrieved(string itemId, string content)
    signal linkPreviewFetched(string url, var metadata, string itemId)
    
    function decodeUriString(str) {
        try {
            return decodeURIComponent(str);
        } catch (e) {
            return str;
        }
    }

    function initialize() {
        initDbProcess.command = ["sh", "-c", "sqlite3 " + dbPath + " < " + schemaPath];
        initDbProcess.running = true;
    }

    function ensureBinaryDataDir() {
        ensureDirProcess.command = ["mkdir", "-p", binaryDataDir];
        ensureDirProcess.running = true;
    }

    function checkClipboard() {
        if (!_initialized || _operationInProgress) return;
        _operationInProgress = true;
        checkAndInsertProcess.command = [checkScriptPath, dbPath, insertScriptPath, binaryDataDir];
        checkAndInsertProcess.running = true;
    }

    function getImageHash(mimeType) {
    }

    function insertTextItemFromFile(hash, tmpFile) {
    }
    
    function insertFileItemFromFile(hash, tmpFile) {
    }
    
    property Process writeTmpProcess: Process {
        property string itemHash: ""
        property string itemContent: ""
        running: false
        
        stdout: StdioCollector {
            waitForEnd: true
            
            onStreamFinished: {
            }
        }
    }

    function insertImageItem(hash, mimeType) {
    }

    function list() {
        if (!_initialized) return;
        _operationInProgress = true;
        // Use JSON mode for reliable parsing, with timeout to avoid locks
        // ORDER BY pinned DESC, display_index ASC to show pinned items first (ordered by index), then unpinned items (ordered by index)
        listProcess.command = ["sh", "-c", 
            "sqlite3 '" + dbPath + "' <<'EOSQL'\n.timeout 5000\n.mode json\nSELECT id, mime_type, preview, is_image, binary_path, content_hash, size, created_at, pinned, alias, display_index FROM clipboard_items ORDER BY pinned DESC, display_index ASC, updated_at DESC, id DESC LIMIT 100;\nEOSQL"
        ];
        listProcess.running = true;
    }

    function getFullContent(id) {
        if (!_initialized) return;
        getContentProcess.itemId = id;
        getContentProcess.command = ["sh", "-c", "sqlite3 '" + dbPath + "' '.timeout 5000' 'SELECT full_content FROM clipboard_items WHERE id = " + id + ";'"];
        getContentProcess.running = true;
    }

    function deleteItem(id) {
        if (!_initialized) return;
        _operationInProgress = true;
        deleteProcess.itemId = id;
        
        deleteProcess.command = ["sh", "-c", 
            "HASH=$(sqlite3 '" + dbPath + "' '.timeout 5000' 'SELECT content_hash FROM clipboard_items WHERE id = " + id + ";'); " +
            "sqlite3 '" + dbPath + "' '.timeout 5000' 'DELETE FROM clipboard_items WHERE id = " + id + ";'; " +
            "echo \"$HASH\""
        ];
        deleteProcess.running = true;
    }

    function clear() {
        if (!_initialized) return;
        clearProcess.command = ["sh", "-c", 
            "sqlite3 '" + dbPath + "' '.timeout 5000' 'DELETE FROM clipboard_items WHERE pinned = 0;'; " +
            "wl-copy --clear 2>/dev/null || true"
        ];
        clearProcess.running = true;
    }

    function togglePin(id) {
        if (!_initialized) return;
        _operationInProgress = true;
        togglePinProcess.itemId = id;
        togglePinProcess.command = ["sh", "-c", 
            "sqlite3 '" + dbPath + "' <<'EOSQL'\n" +
            ".timeout 5000\n" +
            "BEGIN TRANSACTION;\n" +
            "-- Toggle pin status\n" +
            "UPDATE clipboard_items SET pinned = CASE WHEN pinned = 1 THEN 0 ELSE 1 END WHERE id = " + id + ";\n" +
            "-- Get new pinned status\n" +
            "-- If item is now pinned (pinned=1), set its index to 0 and shift others\n" +
            "-- If item is now unpinned (pinned=0), set its index to 0 and shift others\n" +
            "UPDATE clipboard_items SET display_index = CASE \n" +
            "  WHEN id = " + id + " THEN 0\n" +
            "  ELSE display_index + 1\n" +
            "END WHERE pinned = (SELECT pinned FROM clipboard_items WHERE id = " + id + ");\n" +
            "-- Compact indices to remove gaps for both pinned and unpinned\n" +
            "WITH reindexed_pinned AS (\n" +
            "  SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx\n" +
            "  FROM clipboard_items WHERE pinned = 1\n" +
            ")\n" +
            "UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed_pinned WHERE reindexed_pinned.id = clipboard_items.id) WHERE pinned = 1;\n" +
            "WITH reindexed_unpinned AS (\n" +
            "  SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx\n" +
            "  FROM clipboard_items WHERE pinned = 0\n" +
            ")\n" +
            "UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed_unpinned WHERE reindexed_unpinned.id = clipboard_items.id) WHERE pinned = 0;\n" +
            "COMMIT;\n" +
            "EOSQL"
        ];
        togglePinProcess.running = true;
    }

    function setAlias(id, alias) {
        if (!_initialized) return;
        _operationInProgress = true;
        setAliasProcess.itemId = id;
        var escapedAlias = alias.replace(/'/g, "''");
        if (alias.trim() === "") {
            setAliasProcess.command = ["sh", "-c", "sqlite3 '" + dbPath + "' '.timeout 5000' 'UPDATE clipboard_items SET alias = NULL WHERE id = " + id + ";'"];
        } else {
            setAliasProcess.command = ["sh", "-c", "sqlite3 '" + dbPath + "' '.timeout 5000' \"UPDATE clipboard_items SET alias = '" + escapedAlias + "' WHERE id = " + id + ";\""];
        }
        setAliasProcess.running = true;
    }

    function decodeToDataUrl(id, mime) {
        if (imageDataById[id]) {
            return;
        }
        
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === id) {
                var binaryPath = items[i].binaryPath;
                if (binaryPath && binaryPath.length > 0) {
                    loadImageProcess.itemId = id;
                    loadImageProcess.mimeType = mime;
                    loadImageProcess.command = ["base64", "-w", "0", binaryPath];
                    loadImageProcess.running = true;
                }
                break;
            }
        }
    }

    function getImageData(id) {
        return imageDataById[id] || "";
    }
    
    function fetchLinkPreview(url, itemId) {
        if (!_initialized) return;
        
        if (linkPreviewCache[url]) {
            Qt.callLater(function() {
                root.linkPreviewFetched(url, linkPreviewCache[url], itemId);
            });
            return;
        }
        
        linkPreviewProcess.requestUrl = url;
        linkPreviewProcess.requestItemId = itemId;
        linkPreviewProcess.command = ["python3", linkPreviewScriptPath, url, "5"];
        linkPreviewProcess.running = true;
    }
    
    function reorderItem(itemId, newIndex) {
        if (!_initialized) return;
        
        var item = null;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                item = items[i];
                break;
            }
        }
        
        if (!item) return;
        
        var isPinned = item.pinned ? 1 : 0;
        
        if (newIndex < 0) newIndex = 0;
        
        reorderProcess.command = ["sh", "-c", 
            "sqlite3 '" + dbPath + "' <<'EOSQL'\n" +
            ".timeout 5000\n" +
            "BEGIN TRANSACTION;\n" +
            "-- Shift other items to make room\n" +
            "UPDATE clipboard_items SET display_index = display_index + 1 WHERE pinned = " + isPinned + " AND display_index >= " + newIndex + " AND id != " + itemId + ";\n" +
            "-- Set new index for target item\n" +
            "UPDATE clipboard_items SET display_index = " + newIndex + " WHERE id = " + itemId + ";\n" +
            "-- Compact indices to remove gaps\n" +
            "WITH reindexed AS (\n" +
            "  SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx\n" +
            "  FROM clipboard_items WHERE pinned = " + isPinned + "\n" +
            ")\n" +
            "UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed WHERE reindexed.id = clipboard_items.id) WHERE pinned = " + isPinned + ";\n" +
            "COMMIT;\n" +
            "EOSQL"
        ];
        reorderProcess.running = true;
    }
    
    function moveItemUp(itemId) {
        var item = null;
        var currentIdx = -1;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                item = items[i];
                currentIdx = i;
                break;
            }
        }
        
        if (!item || currentIdx < 0) return;
        
        if (currentIdx === 0) return;
        
        var prevItem = items[currentIdx - 1];
        if (prevItem.pinned !== item.pinned) return;
        
        // Optimistic update: Swap in local array
        var temp = items[currentIdx];
        items[currentIdx] = items[currentIdx - 1];
        items[currentIdx - 1] = temp;
        
        listCompleted();
        
        swapItems(itemId, prevItem.id);
    }
    
    function moveItemDown(itemId) {
        var item = null;
        var currentIdx = -1;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                item = items[i];
                currentIdx = i;
                break;
            }
        }
        
        if (!item || currentIdx < 0) return;
        
        if (currentIdx >= items.length - 1) return;
        
        var nextItem = items[currentIdx + 1];
        if (nextItem.pinned !== item.pinned) return;
        
        // Optimistic update: Swap in local array
        var temp = items[currentIdx];
        items[currentIdx] = items[currentIdx + 1];
        items[currentIdx + 1] = temp;
        
        listCompleted();
        
        swapItems(itemId, nextItem.id);
    }
    
    function swapItems(itemId1, itemId2) {
        if (!_initialized) return;
        
        var cmd = "sqlite3 '" + dbPath + "' <<'EOSQL'\n" +
            ".timeout 5000\n" +
            "BEGIN TRANSACTION;\n" +
            "-- Reindex to ensure unique indices\n" +
            "WITH reindexed_pinned AS (\n" +
            "  SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx\n" +
            "  FROM clipboard_items WHERE pinned = 1\n" +
            ")\n" +
            "UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed_pinned WHERE reindexed_pinned.id = clipboard_items.id) WHERE pinned = 1;\n" +
            "WITH reindexed_unpinned AS (\n" +
            "  SELECT id, ROW_NUMBER() OVER (ORDER BY display_index ASC, updated_at DESC, id DESC) - 1 AS new_idx\n" +
            "  FROM clipboard_items WHERE pinned = 0\n" +
            ")\n" +
            "UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed_unpinned WHERE reindexed_unpinned.id = clipboard_items.id) WHERE pinned = 0;\n" +
            "-- Create temp variables for the swap\n" +
            "CREATE TEMP TABLE IF NOT EXISTS swap_temp (idx1 INTEGER, idx2 INTEGER);\n" +
            "DELETE FROM swap_temp;\n" +
            "INSERT INTO swap_temp (idx1, idx2) \n" +
            "  SELECT \n" +
            "    (SELECT display_index FROM clipboard_items WHERE id = " + itemId1 + "),\n" +
            "    (SELECT display_index FROM clipboard_items WHERE id = " + itemId2 + ");\n" +
            "-- Perform the swap\n" +
            "UPDATE clipboard_items SET display_index = (SELECT idx2 FROM swap_temp) WHERE id = " + itemId1 + ";\n" +
            "UPDATE clipboard_items SET display_index = (SELECT idx1 FROM swap_temp) WHERE id = " + itemId2 + ";\n" +
            "-- Clean up\n" +
            "DELETE FROM swap_temp;\n" +
            "COMMIT;\n" +
            "EOSQL";
            
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        proc.command = ["sh", "-c", cmd];
        
        proc.onExited.connect(function(code) {
             if (code === 0) {
                 Qt.callLater(root.list);
             } else {
                 console.warn("ClipboardService: dynamic swapProcess failed with code:", code);
             }
             proc.destroy();
        });
        
        proc.running = true;
    }
    

    property Process reorderProcess: Process {
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: reorderProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code === 0) {
                Qt.callLater(root.list);
            }
        }
    }
    
    property Process emojiTypeProcess: Process {
        running: false
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("ClipboardService: emojiTypeProcess stderr:", text);
                }
            }
        }
        
        onExited: function(code) {
            if (code !== 0) {
                console.warn("ClipboardService: emojiTypeProcess failed with code:", code);
            }
        }
    }
    
    property Timer emojiTypeTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: {
            emojiTypeProcess.command = ["wtype", "-M", "ctrl", "-P", "v", "-p", "v", "-m", "ctrl"];
            emojiTypeProcess.running = true;
        }
    }
    
    function copyAndTypeEmoji(emojiText) {
        var copyCmd = ["bash", "-c", "echo -n '" + emojiText.replace(/'/g, "'\\''") + "' | wl-copy"];
        var copyProc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        copyProc.command = copyCmd;
        copyProc.running = true;
        
        emojiTypeTimer.start();
    }

    Component.onCompleted: {
        Qt.callLater(() => initialize());
    }
}
