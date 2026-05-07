import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    
    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 8

        // Force a minimum popup width so "Fully charged" / "Time to empty: 5h 12m"
        // never overflow the rounded edge. The Layout.minimumWidth on child rows
        // does NOT propagate up to the popup's implicit sizing on its own.
        implicitWidth: 220

        // Header
        Row {
            id: header
            spacing: 8

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                fill: 0
                font.weight: Font.Medium
                text: "battery_android_full"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Battery")
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.normal
                }
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        // This row is hidden when the battery is full.
        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.minimumWidth: 200
            property bool rowVisible: {
                let timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                let power = Battery.energyRate;
                return !(Battery.chargeState == 4 || timeValue <= 0 || power <= 0.01);
            }
            visible: rowVisible
            opacity: rowVisible ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }

            MaterialSymbol {
                text: "schedule"
                color: Appearance.colors.colOnSurfaceVariant
                iconSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                text: Battery.isCharging ? Translation.tr("Time to full:") : Translation.tr("Time to empty:")
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colOnSurfaceVariant
                text: {
                    function formatTime(seconds) {
                        var h = Math.floor(seconds / 3600);
                        var m = Math.floor((seconds % 3600) / 60);
                        if (h > 0)
                            return `${h}h, ${m}m`;
                        else
                            return `${m}m`;
                    }
                    if (Battery.isCharging)
                        return formatTime(Battery.timeToFull);
                    else
                        return formatTime(Battery.timeToEmpty);
                }
            }
        }

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.minimumWidth: 200

            property bool rowVisible: !(Battery.chargeState != 4 && Battery.energyRate == 0)
            visible: rowVisible
            opacity: rowVisible ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }

            MaterialSymbol {
                text: "bolt"
                color: Appearance.colors.colOnSurfaceVariant
                iconSize: Appearance.font.pixelSize.normal
            }

            StyledText {
                text: {
                    if (Battery.chargeState == 4) {
                        return Translation.tr("Fully charged");
                    } else if (Battery.chargeState == 1) {
                        return Translation.tr("Charging:");
                    } else {
                        return Translation.tr("Discharging:");
                    }
                }
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colOnSurfaceVariant
                text: {
                    if (Battery.chargeState == 4) {
                        return "";
                    } else {
                        return `${Battery.energyRate.toFixed(2)}W`;
                    }
                }
            }
        }
    }
}
