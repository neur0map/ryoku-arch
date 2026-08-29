import QtQuick

QtObject {
    required property string screenName
    property bool ready: false
    property string path: ""
    property int revision: 0
    property string fit: "Cover"
    property bool live: false
    property var transition: null

    function apply(line: string): bool {
        try {
            const state = JSON.parse(line);
            const entry = (state.outputs && state.outputs[screenName]) || state.default;
            if (!entry)
                return false;
            ready = true;
            fit = entry.fit || "Cover";
            live = entry.live === true;
            transition = entry.transition || null;
            path = entry.path || "";
            revision = entry.revision || 0;
            return true;
        } catch (error) {
            return false;
        }
    }
}
