import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../shapes/"
import "../services/"
import "../"

PopupWindow {
	id: root

	required property var anchorWindow

	readonly property int toastWidth: Theme.notificationToastWidth+(fw/2)
	readonly property int fw: Theme.notchRadius
	readonly property int fh: Theme.notchRadius

	implicitWidth:  toastWidth + fw
	implicitHeight: 180

	anchor.window: root.anchorWindow
	anchor.rect: Qt.rect(
		root.anchorWindow.width - toastWidth/2-fw+1,
		-Theme.notchHeight-20,
		toastWidth,
		Theme.notchHeight
	)
	anchor.gravity:    Edges.Bottom
	anchor.adjustment: PopupAdjustment.None

	color:   "transparent"
	visible: windowVisible

	property bool windowVisible: false
	property bool showing:       false
	property var  current:       null
	property var  queue:         []

	Connections {
		target: NotificationService
		function onNotificationAdded(n) {
			if (!n || !n.tracked) return
			if (root.current === null) {
				root.startShow(n)
			} else {
				root.queue = [...root.queue, n]
			}
		}
	}

	function startShow(n) {
		root.current       = n
		root.showing       = false
		root.windowVisible = true
		slideInTimer.restart()
		Popups.notificationToastOpen = false
	}

	function startDismiss() {
		autoTimer.stop()
		root.showing = false
		Popups.notificationToastOpen = false
		slideOutTimer.restart()
	}

	Connections {
		target:               root.current
		ignoreUnknownSignals: true
		function onClosed() { root.startDismiss() }
	}

	Timer {
		id:          slideInTimer
		interval:    30
		onTriggered: { root.showing = true; Popups.notificationToastOpen = true; autoTimer.restart() }
	}

	Timer {
		id:          autoTimer
		interval:    5000
		onTriggered: root.startDismiss()
	}

	Timer {
		id:       slideOutTimer
		interval: Theme.animDuration + 20
		onTriggered: {
			if (root.queue.length > 0) {
				const next = root.queue[0]
				root.queue = root.queue.slice(1)
				root.startShow(next)
			} else {
				root.current       = null
				root.windowVisible = false
			}
		}
	}

	// ── Card ───────────────────────────────────────────────────
	Item {
		id:            card
		anchors.right: parent.right
		anchors.top:   parent.top
		clip:           true


		width: root.showing 
		? root.toastWidth + root.fw 
		: root.fw

		height: root.showing 
		? (cardCol.y + cardCol.implicitHeight + 24 + root.fh) 
		: root.fh

		Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
		Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

		PopupShape {
			anchors.fill: parent
			attachedEdge: "right"
			color:        Theme.background
			radius:       Theme.cornerRadius
			flareWidth:   root.fw
			flareHeight:  root.fh
		}

		Rectangle {
			anchors {
				right:        parent.right
				top:          parent.top
				bottom:       parent.bottom
				topMargin:    fh*1.2
				bottomMargin: fh*1.2
				rightMargin:  root.fw
			}
			width:  3
			radius: 2
			color: {
				if (!root.current) return "#ABB2BF"
				switch (root.current.urgency) {
					case NotificationUrgency.Critical: return "#e06c75"
					case NotificationUrgency.Low:      return Qt.rgba(1,1,1,0.25)
					default:                           return "#ABB2BF"
				}
			}
		}

		Item {
			anchors.fill: parent
			opacity: root.showing ? 1 : 0
			Behavior on opacity { NumberAnimation { duration: 150 } }
			Rectangle {
				id: progressBar
				anchors {
					right:       parent.right
					rightMargin: root.fw
					bottom:      cardCol.bottom
					bottomMargin: -10
				}
				height:  2
				radius:  1
				color:   Theme.active
				opacity: 0.5

				property bool running: false

				// Use toastWidth so the bar stays within the visible body, not the flare
				width: running ? 0 : root.toastWidth - 10
				Behavior on width {
					NumberAnimation { duration: 5000; easing.type: Easing.Linear }
				}

				Connections {
					target: root
					function onShowingChanged() {
						if (root.showing) {
							progressBar.running = false
							progressTick.restart()
						} else {
							progressBar.running = false
						}
					}
				}

				Timer {
					id:          progressTick
					interval:    16
					onTriggered: progressBar.running = true
				}
			}

			Column {
				id: cardCol
				anchors {
					left:       parent.left;  leftMargin:  14
					right:      parent.right; rightMargin: root.fw + 6

				}
				spacing: 2
				bottomPadding: 10
				y: root.fh + 6
				// No fixed height — sizes to content

				Row {
					id:      headerRow
					width:   parent.width
					height: 40
					spacing: 8

					Item {
						width:  16
						height: 16
						anchors.verticalCenter: parent.verticalCenter

						Image {
							id:           toastIcon
							anchors.fill: parent
							source: {
								var ic = root.current?.appIcon ?? ""
								if (ic === "") return ""
								if (ic.startsWith("/")) return "file://" + ic
								return "image://icon/" + ic
							}
							fillMode:          Image.PreserveAspectFit
							smooth:            true
							visible:           status === Image.Ready
							sourceSize.width:  16
							sourceSize.height: 16
						}
						Rectangle {
							anchors.fill: parent
							radius:       width / 2
							color:        Qt.rgba(1,1,1,0.1)
							visible:      toastIcon.status !== Image.Ready
							Text {
								anchors.centerIn: parent
								text:           (root.current?.appName ?? "?").charAt(0).toUpperCase()
								color:          Theme.text
								font.pixelSize: 9
								font.bold:      true
							}
						}
					}

					Text {
						width:                  parent.width - 16 - 24 - parent.spacing * 2
						anchors.verticalCenter: parent.verticalCenter
						text:                   root.current?.appName ?? ""
						color:                  Theme.subtext
						font.pixelSize:         11
						elide:                  Text.ElideRight
					}

					Item {
						width:  20
						height: 20
						anchors.verticalCenter: parent.verticalCenter
						Rectangle {
							anchors.fill: parent
							radius:       width / 2
							color:        xHover.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
							Behavior on color { ColorAnimation { duration: 100 } }
						}
						Text {
							anchors.centerIn: parent
							text:             "✕"
							color:            Theme.subtext
							font.pixelSize:   9
						}
						HoverHandler { id: xHover }
						TapHandler   { onTapped: root.startDismiss() }
					}
				}

				Text {
					width:            parent.width
					text:             root.current?.summary ?? ""
					color:            Theme.text
					font.pixelSize:   13
					font.bold:        true
					wrapMode:         Text.WordWrap
					maximumLineCount: 2
					elide:            Text.ElideRight
					visible:          text !== ""
				}

				Text {
					width:            parent.width
					text:             root.current?.body ?? ""
					color:            Theme.subtext
					font.pixelSize:   12
					wrapMode:         Text.WordWrap
					maximumLineCount: 2
					elide:            Text.ElideRight
					textFormat:       Text.StyledText
					visible:          text !== ""
				}

				Row {
					spacing:    6
					topPadding: 2
					visible:    (root.current?.actions?.length ?? 0) > 0

					Repeater {
						model: root.current?.actions ?? []
						delegate: Item {
							required property var modelData
							width:  actionLbl.width + 20
							height: 24
							Rectangle {
								anchors.fill: parent
								radius:       4
								color:        actHover.containsMouse
								? Qt.rgba(1,1,1,0.18)
								: Qt.rgba(1,1,1,0.08)
								Behavior on color { ColorAnimation { duration: 100 } }
							}
							Text {
								id:               actionLbl
								anchors.centerIn: parent
								text:             modelData?.text ?? ""
								color:            Theme.text
								font.pixelSize:   11
							}
							HoverHandler { id: actHover }
							TapHandler {
								onTapped: {
									modelData?.invoke()
									root.startDismiss()
								}
							}
						}
					}
				}
			}
		}
	}
}
