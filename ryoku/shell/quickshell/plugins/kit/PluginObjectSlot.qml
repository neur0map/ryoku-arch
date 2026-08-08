import QtQuick

// Loads a plugin object without tearing down the working instance first. A new
// component is created and configured off to the side; only a successful object
// replaces the current one. Content-specific parent directory URLs invalidate
// every relative QML and JavaScript dependency in the plugin tree.
Item {
    id: slot

    property string source: ""
    property var configure: null
    property bool fill: false
    property var item: null
    property int _generation: 0

    width: 0
    height: 0

    onSourceChanged: rebuild()
    Component.onCompleted: rebuild()

    function rebuild() {
        const generation = ++slot._generation;
        if (!source || source.length === 0) {
            const previous = item;
            item = null;
            if (previous)
                previous.destroy();
            return;
        }
        const requestedSource = source;
        const previous = item;
        const component = Qt.createComponent(requestedSource);
        function publish() {
            if (generation !== slot._generation || requestedSource !== slot.source)
                return;
            if (component.status === Component.Ready) {
                const next = component.createObject(slot);
                if (!next) {
                    console.warn("PluginObjectSlot: could not create", requestedSource);
                    return;
                }
                if (slot.fill && next.anchors)
                    next.anchors.fill = slot;
                if (slot.configure)
                    slot.configure(next);
                slot.item = next;
                if (previous && previous !== next)
                    previous.destroy();
            } else if (component.status === Component.Error) {
                console.warn("PluginObjectSlot:", component.errorString());
            }
        }
        if (component.status === Component.Loading)
            component.statusChanged.connect(publish);
        else
            publish();
    }
}
