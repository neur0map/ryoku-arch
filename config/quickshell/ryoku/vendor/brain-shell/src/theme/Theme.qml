pragma Singleton
import QtQuick
import "."

QtObject {
    // ── Color loader — watches matugen output and updates live ────────────────
    property var _loader: ColorLoader { id: loader }

    // ── Colors — bound to loader, update automatically when matugen runs ──────
    property color background: loader.background
    property color active:     loader.active
    property color text:       loader.text
    property color subtext:    loader.subtext
    property color icon:       loader.icon
    property color border:     loader.border
    property color iconFont:   loader.iconFont

    // --- Workspace Visuals ---
    property color wsBackground: "#20000000"
    property color wsActive:     "#FFFFFF"
    property color wsOccupied:   "#80FFFFFF"
    property color wsEmpty:      "#30FFFFFF"
    property color wsOverlay:    "#CC1e1e2e"
    property color wsUrgent:     "#fa6b94"

    // --Bar Toggle--
    property bool barEnabled: false

    // -- Bar Sizes --
    property int borderWidth:   6
    property int cornerRadius:  17
    property int notchRadius:   15
    property int notchHeight:   40
    property int exclusionGap:  34
    property int spacing:       10

    // -- Notch Content Padding --
    // Space added around the content inside each notch
    property int notchPadding:           16   // horizontal padding each side
    property int notchHorizontalPadding: 20
    property int notchVerticalPadding:   10
    property int notchSideMargin:        10

    // -- Notch Width Constraints --
    // Each notch sizes itself to its content, clamped between min and max.
    property int lNotchMinWidth: 180
    property int lNotchMaxWidth: 360

    property int cNotchMinWidth: 300
    property int cNotchMaxWidth: 360

    property int rNotchMinWidth: 200
    property int rNotchMaxWidth: 360

    // -- Dashboard Dimensions --
    // Target size the center notch expands to when the dashboard is open.
    property int dashboardWidth:  900
    property int dashboardHeight: 520

    // -- Notifications Popup Width --
    property int notificationsWidth: 400
    property int notificationToastWidth: notificationsWidth / 1.2
    property int networkPopupWidth:  480

    // -- Popup Size Constraints --
    property int popupMinWidth:   160
    property int popupMaxWidth:   420
    property int popupMinHeight:   80
    property int popupMaxHeight:  520
    property int popupPadding:     16

    // -- Workspace Dot Sizes --
    property int wsDotSize:     10
    property int wsActiveWidth: 24
    property int wsSpacing:     6
    property int wsPadding:     8
    property int wsRadius:      16

    // -- Animations --
    property int animDuration: 320
}
