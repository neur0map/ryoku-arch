import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

/**
 * Thumbnail image. It currently generates to the right place at the right size, but does not handle metadata/maintenance on modification.
 * See Freedesktop's spec: https://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property bool isVideo: Images.isValidVideoByName(sourcePath)
    property string thumbnailPath: {
        if (sourcePath.length === 0) return ""

        let cleanPath = FileUtils.trimFileProtocol(String(sourcePath ?? ""))
        if (!cleanPath.startsWith("/"))
            cleanPath = Quickshell.env("PWD") + "/" + cleanPath

        const encodedParts = cleanPath.split("/").map(part => {
            return encodeURIComponent(part).replace(/[!'()*]/g, function(c) {
                return '%' + c.charCodeAt(0).toString(16)
            })
        })

        const md5Hash = Qt.md5("file://" + encodedParts.join("/"))
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`
    }
    source: thumbnailPath

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    function _ensureThumbnail() {
        if (!root.generateThumbnail) return
        if (!root.sourcePath || root.sourcePath.length === 0) return
        if (Wallpapers.thumbnailGenerationRunning) return
        Wallpapers.ensureThumbnailForPath(root.sourcePath, root.thumbnailSizeName)
    }

    onStatusChanged: {
        if (status === Image.Error && generateThumbnail) {
            root._ensureThumbnail()
        }
    }

    onSourcePathChanged: {
        if (!sourcePath || sourcePath.length === 0) {
            root.source = "";
            return;
        }

        root.source = root.thumbnailPath
    }

    onThumbnailSizeNameChanged: {
        if (!sourcePath || sourcePath.length === 0) return;
        root.source = root.thumbnailPath
    }

    onSourceSizeChanged: {
        if (!root.generateThumbnail) return;
        if (root.status === Image.Ready) return;
        root.source = root.thumbnailPath
    }
}
