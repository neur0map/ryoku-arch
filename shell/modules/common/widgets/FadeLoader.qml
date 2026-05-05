import QtQuick

import qs.modules.common
import qs.modules.common.widgets

Loader {
    id: root
    property bool shown: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    active: shown

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
}
