import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    function resolveIcon(className) {
        if (!className || className.length === 0)
            return "";

        const original = className;
        const normalized = className.toLowerCase();
        // 1. Exact icon name
        if (Quickshell.iconPath(original, true).length > 0)
            return original;

        // 2. Normalized guess
        if (Quickshell.iconPath(normalized, true).length > 0)
            return normalized;

        // 3. Dashed guess
        const dashed = normalized.replace(/\s+/g, "-");
        if (Quickshell.iconPath(dashed, true).length > 0)
            return dashed;

        // 4. Extension guess
        const ext = original.split(".").pop().toLowerCase();
        if (Quickshell.iconPath(ext, true).length > 0)
            return ext;

        return "";
    }

    function trimFileProtocol(str) {
        let s = str;
        if (typeof s !== "string")
            s = str.toString();

        // Convert to string if it's an url or whatever
        return s.startsWith("file://") ? s.slice(7) : s;
    }

    function isVideo(path) {
        if (!path)
            return false;

        // Convert QUrl → string if needed
        let p = path.toString ? path.toString() : path;
        // Strip file://
        if (p.startsWith("file://"))
            p = p.replace("file://", "");

        const ext = p.split(".").pop().toLowerCase();
        return ["mp4", "mkv", "webm", "mov", "avi", "m4v"].includes(ext);
    }

    function createFile(filePath, callback) {
        if (!filePath)
            return ;

        let p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root);
        p.command = ["touch", filePath];
        p.onExited.connect(function() {
            console.debug("Created file:", filePath, "exit code:", p.exitCode);
            p.destroy();
            if (callback)
                callback(true);

        });
        p.running = true;
    }

    function removeFile(filePath, callback) {
        if (!filePath)
            return ;

        let p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root);
        p.command = ["rm", "-f", filePath];
        p.onExited.connect(function() {
            console.debug("Removed file:", filePath, "exit code:", p.exitCode);
            p.destroy();
            if (callback)
                callback(true);

        });
        p.running = true;
    }

    function renameFile(oldPath, newPath, callback) {
        if (!oldPath || !newPath || oldPath === newPath)
            return ;

        let p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root);
        p.command = ["mv", oldPath, newPath];
        p.onExited.connect(function() {
            console.debug("Renamed file:", oldPath, "→", newPath, "exit code:", p.exitCode);
            p.destroy();
            if (callback)
                callback(true);

        });
        p.running = true;
    }

}