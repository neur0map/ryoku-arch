import QtQuick

QtObject {
    required property string screenName
    property bool ready: false
    property string path: ""
    property int revision: 0
    property string fit: "Cover"
    property var transition: null
    property string depth: ""
    property int depthRev: 0
    property string videoPath: ""
    property bool live: false

    function apply(line: string): bool {
        try {
            const state = JSON.parse(line);
            const entry = (state.outputs && state.outputs[screenName]) || state.default;
            if (!entry)
                return false;
            ready = true;
            fit = entry.fit || "Cover";
            transition = entry.transition || null;
            path = entry.path || "";
            depth = entry.depth || "";
            depthRev = entry.depthRev || 0;
            revision = entry.revision || 0;
            videoPath = entry.videoPath || "";
            live = entry.live === true;
            return true;
        } catch (error) {
            return false;
        }
    }
}
