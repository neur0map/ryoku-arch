import QtQuick
import Quickshell
import "../shapes"
import "../services"
import "../components"
import "../"

PopupWindow {
	id: root

	required property var anchorWindow

	readonly property int fw: Theme.cornerRadius
	readonly property int fh: Theme.cornerRadius

	readonly property var pageHeights: ({
		"power":       270,
		"performance": 190,
		"stats":       250
	})
	readonly property var pageWidths: ({
		"power":       220,
		"performance": 260,
		"stats":       390
	})

	readonly property int contentWidth:  pageWidths[page]  ?? 220
	readonly property int contentHeight: pageHeights[page] ?? 220

	property string page: "power"

	color:   "transparent"
	visible: slide.windowVisible
	mask: Region { item: maskProxy }

	implicitWidth:  (pageWidths["stats"]  ?? 220) + fw
	implicitHeight: (pageHeights["stats"] ?? 220) + fh * 2

	anchor.window:  anchorWindow
	anchor.gravity: Edges.Right
	anchor.rect: Qt.rect(
		0,
		anchorWindow.height / 2,
		anchorWindow.width,
		implicitHeight
	)
	
	Item {
		id:      maskProxy
		x:       0
		y:       (root.implicitHeight - sizer.height) / 2-root.fh
		width:   sizer.width
		height:  sizer.height
	}

	PopupSlide {
		id: slide
		anchors.fill: parent
		edge:             "left"
		hoverEnabled:     false
		triggerHovered:   Popups.archMenuTriggerHovered
		open:             Popups.archMenuOpen
		onCloseRequested: Popups.archMenuOpen = false

		Connections {
			target: Popups
			function onArchMenuOpenChanged() {
				if (!Popups.archMenuOpen) archResetTimer.restart()
			}
		}

		Timer {
			id: archResetTimer
			interval: Theme.animDuration + 20
			onTriggered: switcher.reset()
		}

		Item {
			id: sizer
			anchors.left:           parent.left
			anchors.verticalCenter: parent.verticalCenter
			clip: true

			width:  root.contentWidth  + root.fw
			height: root.contentHeight + root.fh * 2

			Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
			Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

			PopupShape {
				id: bg
				anchors.fill: parent
				attachedEdge: "left"
				color:        Theme.background
				radius:       Theme.cornerRadius
				flareWidth:   root.fw
				flareHeight:  root.fh
			}

			Item {
				anchors {
					fill:         parent
					leftMargin:   root.fw - 4
					rightMargin:  8
					topMargin:    root.fh + 6
					bottomMargin: root.fh + 6
				}

				Row {
					anchors.fill: parent
					spacing: 8

					// ── Tab switcher — left side ───────────────────────────────
					TabSwitcher {
						id: switcher
						orientation: "vertical"
						height: parent.height/1.5
						anchors.verticalCenter: parent.verticalCenter
						model: [
							{ key: "power",       icon: "⏻" },
							{ key: "stats",       icon: "≡" },
						]
						currentPage: root.page
						onPageChanged: function(key) { root.page = key }
					}

					Rectangle {
						width: 1; height: parent.height
						color: Qt.rgba(1, 1, 1, 0.1)
					}

					// ── Page content ──────────────────────────────────────────
					Item {
						width:  parent.width - switcher.implicitWidth - 1 - parent.spacing * 2
						height: parent.height
						clip:   true

						PopupPage {
							anchors.fill: parent
							visible: root.page === "power"

							PowerMenu {
								width: parent.width
							}
						}

						PopupPage {
							anchors.fill: parent
							visible: root.page === "stats"

							SystemStats {
								width:  parent.width
								height: root.contentHeight - root.fh * 2 - 12 - 16
							}
						}
					}
				}
			}
		}
	}
}
