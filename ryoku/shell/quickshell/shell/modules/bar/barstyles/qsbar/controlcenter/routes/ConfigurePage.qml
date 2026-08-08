import QtQuick
import "../../modules"
import "../kit/Routes.js" as Routes

// The CONFIGURE landing. Ported from Shibumi's ConfigureLandingPage: a left route
// list (icon + title + desc, with hover/selected states) wired to a live Canvas
// bezier graph that fans each route's source port into a single destination port
// on the right preview stage. The stage shows a SemanticPreview keyed by the
// hovered (else selected) route. Clicking a route calls cc.open(routeId), which
// hands off to the ControlCenter's page motion. Dark-skinned; all colour/geometry
// comes from `root` (the qsbar Theme). Bindings are null-safe: the page may exist
// briefly before `root`/`cc` are assigned by PageMotionStage.
Item {
    id: page
    property var root: null
    property var cc: null

    readonly property var routes: Routes.ROUTES
    property int hoveredIndex: -1
    property int selectedIndex: 0

    readonly property int previewIndex: {
        var c = hoveredIndex >= 0 ? hoveredIndex : selectedIndex
        return Math.max(0, Math.min(c, routes.length - 1))
    }
    readonly property var previewRoute: routes.length > 0 ? routes[previewIndex] : null
    readonly property string previewRouteId: previewRoute ? previewRoute.id : ""

    // ── layout + graph geometry ──
    readonly property int rowH: 56
    readonly property int rowGap: 10
    readonly property int graphGap: 46       // horizontal run for the bezier fan
    readonly property int portOffset: 8      // source-port overhang past the cards

    // mirrored so the Canvas can repaint when the live palette shifts
    property color graphAccent: root ? root.seal : "#c4746e"
    property color graphInk:    root ? root.ink  : "#c5c9c5"

    function openRoute(index) {
        if (index < 0 || index >= routes.length) return
        page.selectedIndex = index
        if (page.cc) page.cc.open(routes[index].id)
    }

    activeFocusOnTab: true
    Keys.onUpPressed: function (event) {
        page.selectedIndex = Math.max(0, page.selectedIndex - 1)
        event.accepted = true
    }
    Keys.onDownPressed: function (event) {
        page.selectedIndex = Math.min(page.routes.length - 1, page.selectedIndex + 1)
        event.accepted = true
    }
    Keys.onReturnPressed: function (event) { page.openRoute(page.selectedIndex); event.accepted = true }
    Keys.onEnterPressed:  function (event) { page.openRoute(page.selectedIndex); event.accepted = true }
    Keys.onEscapePressed: function (event) { if (page.cc) page.cc.close(); event.accepted = true }

    UiText {
        id: intro
        anchors.top: parent.top
        anchors.left: parent.left
        text: "CHOOSE WHAT TO CONFIGURE"
        color: page.root ? page.root.sumiHi : "#888888"
        font.family: page.root ? page.root.mono : "monospace"
        font.pixelSize: 10
        font.letterSpacing: 1
    }

    Item {
        id: graph
        anchors.top: intro.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // ── the bezier connection graph (below the cards, above the stage) ──
        Canvas {
            id: graphCanvas
            z: 2
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                if (!page.root) return
                var acc = page.graphAccent
                var ink = page.graphInk
                var startX = routeColumn.x + routeColumn.width + page.portOffset
                var endX = previewStage.x
                var endY = previewStage.y + previewStage.height / 2
                ctx.lineCap = "round"
                for (var i = 0; i < page.routes.length; i++) {
                    var startY = routeColumn.y + i * (page.rowH + page.rowGap) + page.rowH / 2
                    var selected = i === page.selectedIndex
                    var hovered = i === page.hoveredIndex
                    var col = selected ? acc
                        : hovered ? Qt.rgba(acc.r, acc.g, acc.b, 0.58)
                            : Qt.rgba(ink.r, ink.g, ink.b, 0.15)
                    ctx.beginPath()
                    ctx.moveTo(startX, startY)
                    ctx.bezierCurveTo(
                        startX + (endX - startX) * 0.55, startY,
                        endX - (endX - startX) * 0.55, endY,
                        endX, endY)
                    ctx.strokeStyle = col
                    ctx.lineWidth = selected ? 1.7 : hovered ? 1.25 : 1
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.arc(startX, startY, 3.6, 0, Math.PI * 2)
                    ctx.fillStyle = col
                    ctx.fill()
                }
                // destination port — always accent
                ctx.beginPath()
                ctx.arc(endX, endY, 4.4, 0, Math.PI * 2)
                ctx.fillStyle = acc
                ctx.fill()
            }

            Connections {
                target: page
                function onHoveredIndexChanged() { graphCanvas.requestPaint() }
                function onSelectedIndexChanged() { graphCanvas.requestPaint() }
                function onGraphAccentChanged() { graphCanvas.requestPaint() }
                function onGraphInkChanged() { graphCanvas.requestPaint() }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        // ── left: the route list ──
        Item {
            id: routeColumn
            z: 3
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(300, graph.width * 0.42)
            height: page.routes.length * page.rowH
                + Math.max(0, page.routes.length - 1) * page.rowGap

            Repeater {
                model: page.routes
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool selected: page.selectedIndex === index
                    readonly property bool hovered: page.hoveredIndex === index
                    readonly property color acc: page.root ? page.root.seal : "#c4746e"

                    x: 0
                    y: index * (page.rowH + page.rowGap)
                    width: routeColumn.width
                    height: page.rowH
                    radius: page.root ? page.root.tileRadius : 6
                    color: !page.root ? "#22000000"
                        : selected ? Qt.rgba(acc.r, acc.g, acc.b, page.root.fillActiveAlpha)
                            : hovered ? Qt.rgba(acc.r, acc.g, acc.b, page.root.fillHoverAlpha)
                                : page.root.fillIdle
                    border.width: 1
                    border.color: (selected || hovered) ? acc
                        : (page.root ? page.root.sep : "#333333")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 11

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            text: card.modelData.icon
                            color: (card.selected || card.hovered) ? card.acc
                                : (page.root ? page.root.sumiHi : "#888888")
                            font.pixelSize: 19
                            fill: card.selected ? 1 : 0
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x
                            spacing: 2

                            UiText {
                                width: parent.width
                                text: card.modelData.label
                                elide: Text.ElideRight
                                color: (card.selected || card.hovered) ? card.acc
                                    : (page.root ? page.root.ink : "#c5c9c5")
                                font.family: page.root ? page.root.mono : "monospace"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            UiText {
                                width: parent.width
                                text: card.modelData.desc
                                elide: Text.ElideRight
                                color: page.root ? page.root.sumi : "#888888"
                                font.family: page.root ? page.root.mono : "monospace"
                                font.pixelSize: 9
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: page.hoveredIndex = card.index
                        onExited: if (page.hoveredIndex === card.index) page.hoveredIndex = -1
                        onClicked: page.openRoute(card.index)
                    }
                }
            }
        }

        // ── right: the preview stage ──
        Rectangle {
            id: previewStage
            z: 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(1, graph.width - routeColumn.width - page.graphGap)
            radius: page.root ? page.root.tileRadius : 6
            color: page.root ? page.root.frameWeak : "#11ffffff"
            border.width: 1
            border.color: page.root ? page.root.sep : "#333333"

            SemanticPreview {
                id: sem
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                height: Math.max(1, parent.height - 60)
                root: page.root
                routeId: page.previewRouteId
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                spacing: 2

                UiText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: page.previewRoute ? page.previewRoute.label : ""
                    color: page.root ? page.root.ink : "#c5c9c5"
                    font.family: page.root ? page.root.mono : "monospace"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                UiText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: page.previewRoute ? page.previewRoute.desc : ""
                    color: page.root ? page.root.sumi : "#888888"
                    font.family: page.root ? page.root.mono : "monospace"
                    font.pixelSize: 9
                }
            }
        }
    }
}
