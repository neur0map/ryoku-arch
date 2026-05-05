pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    showClickabilityButton: false
    resizable: false
    clickthrough: true

    property string imageSource: Config.options?.overlay?.floatingImage?.imageSource ?? ""
    property real scaleFactor: Config.options?.overlay?.floatingImage?.scale ?? 0.5
    property int imageWidth: 0
    property int imageHeight: 0

    // Override to always save 0 size
    function savePosition(xPos = root.x, yPos = root.y, width = 0, height = 0) {
        root.persistentStateEntry.x = Math.round(xPos);
        root.persistentStateEntry.y = Math.round(yPos);
        root.persistentStateEntry.width = 0
        root.persistentStateEntry.height = 0
    }

    onImageSourceChanged: {
        imageDownloader.running = false;
        if (!root.imageSource || root.imageSource.trim().length === 0) {
            root.imageWidth = 0;
            root.imageHeight = 0;
            animatedImage.source = "";
            root.setSize();
            return;
        }
        imageDownloader.sourceUrl = root.imageSource;
        imageDownloader.filePath = Qt.resolvedUrl(Directories.tempImages + "/" + Qt.md5(root.imageSource))
        imageDownloader.running = true;
    }
    onScaleFactorChanged: {
        setSize();
    }

    function setSize() {
        if (root.imageWidth <= 0 || root.imageHeight <= 0) {
            bg.implicitWidth = 340;
            bg.implicitHeight = 164;
            return;
        }
        bg.implicitWidth = root.imageWidth * root.scaleFactor;
        bg.implicitHeight = root.imageHeight * root.scaleFactor;
    }

    contentItem: OverlayBackground {
        id: bg
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, root.actuallyPinned ? 1 : 0)
        radius: root.contentRadius

        WheelHandler {
            onWheel: (event) => {
                const currentScale = Config.options?.overlay?.floatingImage?.scale ?? 0.5;
                if (event.angleDelta.y < 0) {
                    Config.setNestedValue("overlay.floatingImage.scale", Math.max(0.1, currentScale - 0.1));
                }
                else if (event.angleDelta.y > 0) {
                    Config.setNestedValue("overlay.floatingImage.scale", Math.min(5.0, currentScale + 0.1));
                }
            }
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: bg.width
                height: bg.height
                radius: bg.radius
            }
        }

        AnimatedImage {
            id: animatedImage
            anchors.centerIn: parent
            width: root.imageWidth * root.scaleFactor
            height: root.imageHeight * root.scaleFactor
            sourceSize.width: width
            sourceSize.height: height

            playing: visible
            asynchronous: true
            source: ""
            onStatusChanged: {
                if (status === Image.Ready) {
                    const w = sourceSize.width > 0 ? sourceSize.width : Math.max(1, implicitWidth)
                    const h = sourceSize.height > 0 ? sourceSize.height : Math.max(1, implicitHeight)
                    if (root.imageWidth <= 0 || root.imageHeight <= 0) {
                        root.imageWidth = w;
                        root.imageHeight = h;
                        root.setSize();
                    }
                }
            }

            ImageDownloaderProcess {
                id: imageDownloader
                filePath: Qt.resolvedUrl(Directories.tempImages + "/" + Qt.md5(root.imageSource))
                sourceUrl: root.imageSource

                onDone: (path, width, height) => {
                    root.imageWidth = Number.isFinite(width) && width > 0 ? width : 0;
                    root.imageHeight = Number.isFinite(height) && height > 0 ? height : 0;
                    root.setSize();
                    animatedImage.source = path;
                }
            }
        }
    }
}
