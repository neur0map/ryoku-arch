import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import qs.services as Services
import "../colors" as ColorsModule

Item {
    id: contributionCalendar
    width: 600
    height: 200
    visible: parent.visible

    property var contribs: Services.Github.contributions ?? []
    property bool showLabels: true
    property int cellSize: 12
    property int cellSpacing: 2
    property color backgroundColor: ColorsModule.Colors.surface
    property string username: "neur0map"

    anchors {
        bottom: parent.bottom
        right: parent.right
    }

    function contributionColor(level) {
        // GitHub-style contribution colors
        switch(level) {
            case 0: return "#161b22" // Very dark (empty)
            case 1: return "#0e4429" // Dark green (low)
            case 2: return "#006d32" // Medium green
            case 3: return "#26a641" // Light green
            case 4: return "#39d353" // Bright green (high)
            default: return "#161b22"
        }
    }

    // Main container with rounded corners and shadow
    Rectangle {
        anchors.fill: parent
        color: backgroundColor
        radius: 12
        opacity: 0.95

        // Border
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: ColorsModule.Colors.outline_variant
            radius: 12
        }
    }

    // Main content
    ColumnLayout {
        anchors {
            fill: parent
        }
        spacing: 12

        // Header with GitHub icon and username
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // GitHub icon (using text as fallback since we might not have icon font)
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: ColorsModule.Colors.primary

                Text {
                    anchors.centerIn: parent
                    text: "🐙"
                    font.pixelSize: 16
                    color: ColorsModule.Colors.on_surface
                }
            }

            // Username
            Text {
                text: username
                font.pixelSize: 16
                font.bold: true
                color: ColorsModule.Colors.on_surface
            }

            // Spacer
            Item {
                Layout.fillWidth: true
            }

            // Stats summary
            Text {
                text: {
                    let total = 0
                    let maxLevel = 0
                    for (let i = 0; i < contribs.length; i++) {
                        const level = contribs[i].level ?? contribs[i].intensity ?? 0
                        total += contribs[i].count || 0
                        maxLevel = Math.max(maxLevel, level)
                    }
                    return `${total} contributions in the last year`
                }
                font.pixelSize: 12
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.8
            }
        }

        // Calendar container with scrolling if needed
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Scrollbar styling
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
                contentItem: Rectangle {
                    color: ColorsModule.Colors.primary
                    radius: 3
                    opacity: 0.5
                }
                anchors {
                    right: parent.right
                    rightMargin: 4
                    top: parent.top
                    topMargin: 8
                    bottom: parent.bottom
                    bottomMargin: 8
                }
                spacing: 4
            }

            RowLayout {
                spacing: cellSpacing

                ColumnLayout {
                    spacing: cellSpacing

                    // The calendar grid
                    RowLayout {
                        spacing: cellSpacing

                        Repeater {
                            model: 53  // weeks (max in a year)
                            delegate: ColumnLayout {
                                spacing: cellSpacing

                                property int weekIndex: index

                                Repeater {
                                    model: 7  // days per week
                                    delegate: Rectangle {
                                        width: cellSize
                                        height: cellSize
                                        radius: 3

                                        property int realIndex: weekIndex * 7 + index

                                        // Hover effect
                                        color: {
                                            const baseColor = contributionColor(getLevel())
                                            return hoverHandler.hovered ? Qt.lighter(baseColor, 1.2) : baseColor
                                        }

                                        function getLevel() {
                                            if (realIndex < contributionCalendar.contribs.length) {
                                                const item = contributionCalendar.contribs[realIndex]
                                                return item.level ?? item.intensity ?? 0
                                            }
                                            return 0
                                        }

                                        // Border for empty cells
                                        border.width: getLevel() === 0 ? 1 : 0
                                        border.color: ColorsModule.Colors.outline_variant

                                        HoverHandler {
                                            id: hoverHandler
                                        }

                                        // Tooltip with contribution details
                                        ToolTip.visible: hoverHandler.hovered
                                        ToolTip.delay: 500
                                        ToolTip.timeout: 2000
                                        ToolTip.text: {
                                            if (realIndex < contributionCalendar.contribs.length) {
                                                const item = contributionCalendar.contribs[realIndex]
                                                const date = new Date(item.date).toLocaleDateString(Qt.locale(), "MMM d, yyyy")
                                                const count = item.count || 0
                                                const contributions = count === 1 ? "contribution" : "contributions"
                                                return `${date}: ${count} ${contributions}`
                                            }
                                            return "No data"
                                        }

                                        // Animate on data load
                                        opacity: realIndex < contributionCalendar.contribs.length ? 1 : 0.3
                                        Behavior on opacity { NumberAnimation { duration: 200 } }

                                        // Scale animation on hover
                                        scale: hoverHandler.hovered ? 1.2 : 1
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        // Z-index to ensure scaled cell appears above others
                                        z: hoverHandler.hovered ? 1 : 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Legend
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Text {
                text: "Less"
                font.pixelSize: 10
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.7
            }

            // Color scale
            Repeater {
                model: [0, 1, 2, 3, 4]
                delegate: Rectangle {
                    width: 12
                    height: 12
                    radius: 2
                    color: contributionColor(modelData)
                    border.width: 1
                    border.color: ColorsModule.Colors.outline_variant
                }
            }

            Text {
                text: "More"
                font.pixelSize: 10
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.7
            }
        }
    }

    // Loading indicator
    Loader {
        active: contribs.length === 0
        anchors.centerIn: parent
        sourceComponent: ColumnLayout {
            spacing: 16

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                width: 40
                height: 20
                running: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Loading contributions for " + username + "..."
                font.pixelSize: 12
                color: ColorsModule.Colors.on_surface_variant
            }
        }
    }

    // Error state (if needed)
    Loader {
        active: Services.Github.error !== undefined
        anchors.centerIn: parent
        sourceComponent: ColumnLayout {
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "⚠️"
                font.pixelSize: 32
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Failed to load contributions"
                font.pixelSize: 12
                color: ColorsModule.Colors.error
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Services.Github.error || "Unknown error"
                font.pixelSize: 10
                color: ColorsModule.Colors.errorContainer
                opacity: 0.8
            }
        }
    }
}
