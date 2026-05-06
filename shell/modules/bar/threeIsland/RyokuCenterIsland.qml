import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool showClock: Config.options?.bar?.modules?.kanjiClock ?? true

    implicitWidth: clockHost.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    RyokuKanjiClock {
        id: clockHost
        anchors.centerIn: parent
        visible: root.showClock
    }
}
