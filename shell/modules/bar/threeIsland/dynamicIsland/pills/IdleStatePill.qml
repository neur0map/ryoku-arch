import qs.modules.bar.threeIsland
import QtQuick

// Idle state of the Dynamic Island. Wraps the existing center island
// content (kanji clock + weather + date stack) so behavior is unchanged.
Item {
    id: root
    implicitWidth: inner.implicitWidth
    implicitHeight: inner.implicitHeight

    RyokuCenterIsland {
        id: inner
        anchors.fill: parent
    }
}
