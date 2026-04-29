import QtQuick
import "../"

// Unified tab switcher — horizontal or vertical.
//
// orientation: "horizontal" (default) — Row, fills parent width, tabs spaced equally
//              "vertical"             — Column, fills parent height, tabs spaced equally
//
// Horizontal: icon + label pill, bottom divider. Used by Dashboard.
// Vertical:   icon-only solid pill. Used by ArchMenu.
//
// Model: [{ key: string, icon: string, label?: string }]
// label is optional — only rendered in horizontal orientation.
//
// Sizing contract:
//   Horizontal — parent MUST set width.  implicitHeight is 40.
//   Vertical   — parent MUST set height. implicitWidth  is 40.

Item {
	id: root

	property var    model:       []
	property string currentPage: ""
	property string orientation: "horizontal"   // "horizontal" | "vertical"

	signal pageChanged(string key)

	// ── Default page & reset ──────────────────────────────────────────────────
	// defaultPage auto-resolves to the first model entry.
	// Call reset() from the popup's close handler to restore it off-screen.
	property string defaultPage: model.length > 0 ? model[0].key : ""

	function reset() {
		pageChanged(defaultPage)
	}

	implicitWidth:  orientation === "vertical"   ? 40 : 0
	implicitHeight: orientation === "horizontal" ? 40 : 0

	// ── Scroll cooldown ───────────────────────────────────────────────────────
	property bool scrollBusy: false

	Timer {
		id: scrollCooldown
		interval: 300
		repeat:   false
		onTriggered: root.scrollBusy = false
	}

	WheelHandler {
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		onWheel: function(event) {
			if (root.scrollBusy) return
			root.scrollBusy = true
			scrollCooldown.restart()
			var keys = root.model.map(function(m) { return m.key })
			var idx  = keys.indexOf(root.currentPage)
			if (event.angleDelta.y < 0)
			idx = (idx + 1) % keys.length
			else
			idx = (idx - 1 + keys.length) % keys.length
			root.pageChanged(keys[idx])
		}
	}

	// ── HORIZONTAL layout — Row ───────────────────────────────────────────────
	Row {
		id: hRow
		anchors.fill: parent
		visible: root.orientation === "horizontal"

		Repeater {
			model: root.orientation === "horizontal" ? root.model : []

			delegate: Item {
				id: hTab
				readonly property bool isActive: root.currentPage === modelData.key

				width:  hRow.width / root.model.length
				height: hRow.height

				// Pill background
				Rectangle {
					id: hBg
					anchors.centerIn: parent
					width:  hIcon.implicitWidth + hLabel.implicitWidth + 24
					height: parent.height - 8
					radius: height / 2

					color: hTab.isActive
					? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
					: (hHov.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")

					Behavior on color { ColorAnimation { duration: 120 } }
				}

				// Icon + label
				Row {
					anchors.centerIn: parent
					spacing: 6

					Text {
						id: hIcon
						text:           modelData.icon
						font.pixelSize: 14
						anchors.verticalCenter: parent.verticalCenter
						color: hTab.isActive
						? Theme.active
						: (hHov.hovered ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.4))
						Behavior on color { ColorAnimation { duration: 120 } }
					}

					Text {
						id: hLabel
						visible:        modelData.label !== undefined
						text:           modelData.label ?? ""
						font.pixelSize: 12
						font.weight:    hTab.isActive ? Font.Medium : Font.Normal
						anchors.verticalCenter: parent.verticalCenter
						color: hTab.isActive
						? Theme.active
						: (hHov.hovered ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.4))
						Behavior on color { ColorAnimation { duration: 120 } }
					}
				}

				HoverHandler { id: hHov; cursorShape: Qt.PointingHandCursor }
				MouseArea {
					anchors.fill: parent
					onClicked:    root.pageChanged(modelData.key)
				}
			}
		}
	}

	// Bottom divider — horizontal only
	Rectangle {
		visible:        root.orientation === "horizontal"
		anchors.bottom: parent.bottom
		anchors.left:   parent.left
		anchors.right:  parent.right
		height:         1
		color:          Qt.rgba(1, 1, 1, 0.07)
	}

	// ── VERTICAL layout — Column ──────────────────────────────────────────────
	Column {
		id: vCol
		anchors.centerIn: parent
		visible: root.orientation === "vertical"

		// Distribute tabs evenly: gap = (totalHeight - allTabHeights) / gaps
		// Tab height is fixed at 60px to match original ArchMenu style.
		readonly property int tabH: 60
		spacing: root.model.length > 1
		? (root.height - root.model.length * tabH) / (root.model.length - 1)
		: 0

		Repeater {
			model: root.orientation === "vertical" ? root.model : []

			delegate: Rectangle {
				id: vTab
				readonly property bool isActive: root.currentPage === modelData.key

				width:  40
				height: vCol.tabH
				radius: Theme.cornerRadius * 2

				color: vTab.isActive
				? Theme.active
				: (vHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

				Behavior on color { ColorAnimation { duration: 120 } }

				Text {
					anchors.centerIn: parent
					text:            modelData.icon
					font.pixelSize:  16
					color: vTab.isActive ? Theme.background : Theme.text
					Behavior on color { ColorAnimation { duration: 120 } }
				}

				HoverHandler { id: vHov; cursorShape: Qt.PointingHandCursor }
				MouseArea {
					anchors.fill: parent
					onClicked:    root.pageChanged(modelData.key)
				}
			}
		}
	}
}
