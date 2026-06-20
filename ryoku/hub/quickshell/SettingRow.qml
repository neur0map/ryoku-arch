import QtQuick
import "Singletons"

// One numeric setting in three synced forms: a live slider, manual number entry,
// and -/+ steppers. Every form reports through modified(value); the owner holds
// the value so all three plus the preview stay in lockstep. decimals sets both
// the readout precision and the stored precision.
Item {
    id: row

    property string label: ""
    property string unit: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0

    signal modified(real value)

    implicitWidth: 420
    implicitHeight: 54

    function clamp(v) { return Math.max(row.from, Math.min(row.to, v)); }
    function quant(v) {
        var p = Math.pow(10, row.decimals);
        return Math.round(row.clamp(v) * p) / p;
    }
    function bump(dir) { row.modified(row.quant(row.value + dir * row.step)); }

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.top: parent.top
        text: row.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    // Manual entry plus steppers, top-right.
    Rectangle {
        id: field
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -4
        width: 132
        height: 30
        radius: 9
        color: Theme.surfaceLo
        border.width: 1
        border.color: input.activeFocus ? Theme.ember : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        // minus
        Item {
            id: minus
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 30
            Text {
                anchors.centerIn: parent
                text: "\u2212"
                color: minusH.hovered ? Theme.ember : Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }
            HoverHandler { id: minusH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: row.bump(-1) }
        }

        // plus
        Item {
            id: plus
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 30
            Text {
                anchors.centerIn: parent
                text: "+"
                color: plusH.hovered ? Theme.ember : Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 15
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }
            HoverHandler { id: plusH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: row.bump(1) }
        }

        Row {
            anchors.centerIn: parent
            spacing: 2

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: row.unit !== "" ? 38 : 54
                text: row.value.toFixed(row.decimals)
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: TextInput.AlignHCenter
                selectByMouse: true
                clip: true
                validator: DoubleValidator {
                    bottom: row.from
                    top: row.to
                    decimals: row.decimals
                    notation: DoubleValidator.StandardNotation
                }
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onActiveFocusChanged: {
                    if (activeFocus)
                        selectAll();
                    else
                        text = Qt.binding(() => row.value.toFixed(row.decimals));
                }
                onEditingFinished: {
                    var v = parseFloat(text);
                    if (!isNaN(v)) {
                        var q = row.quant(v);
                        row.modified(q);
                        text = q.toFixed(row.decimals);
                    }
                }
            }

            Text {
                visible: row.unit !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: row.unit
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
    }

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        from: row.from
        to: row.to
        step: row.step
        value: row.value
        onMoved: (v) => row.modified(row.quant(v))
    }
}
