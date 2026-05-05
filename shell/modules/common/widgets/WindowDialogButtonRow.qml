import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RowLayout {
    id: root
    spacing: 4

    // Pull buttons outward horizontally to match the M3 dialog edge-to-edge
    // spec without wasting space. Keep top/bottom margins at 0: a negative
    // bottom margin makes the parent ColumnLayout under-report its height,
    // so the row renders past the dialog's rounded bottom edge and the
    // buttons get clipped (visible as half-visible Cancel/OK pills).
    Layout.leftMargin: -8
    Layout.rightMargin: -8
    Layout.topMargin: 0
    Layout.bottomMargin: 20
}
