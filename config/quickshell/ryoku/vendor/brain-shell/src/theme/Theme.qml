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

    // -- Power Profile: motion freeze --
    // Set true by PowerProfile when entering "powersave". High-visibility
    // Behaviors throughout the shell gate themselves with
    // `enabled: !Theme.staticMode` so motion stops while functions still
    // work normally.
    property bool staticMode: false

    // -- Bar Sizes --
    property int borderWidth:   6
    property int cornerRadius:  17
    property int notchRadius:   15
    property int notchHeight:   32   // Ryoku Patch 10 incremental: was 40 (then 36)
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
    property int dashboardWidth:  690
    property int dashboardHeight: 440

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

    // -- Spatial motion (Material 3 "expressiveDefaultSpatial", per
    //    caelestia-dots/shell). Used for "enter" — drawer-style popups
    //    sliding in from a screen edge with a subtle spring overshoot.
    property int motionSpatialDuration: 500
    property var motionSpatialCurve: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]

    // -- Accel motion (Material 3 "emphasizedAccel"). Used for "exit"
    //    — same popups retracting. Back-loaded: value rises slowly so
    //    opacity stays high while the card visibly slides back into
    //    the bar, then snaps off-screen at the very end. No overshoot.
    //    Without this, exiting with the spatial curve looks like a
    //    fade because opacity drops faster than the slide is visible.
    property int motionAccelDuration: 500
    property var motionAccelCurve: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    // -- Effects motion ("expressiveDefaultEffects"). Used for opacity /
    //    color cross-fades that should feel snappier than spatial moves.
    property int motionEffectsDuration: 200
    property var motionEffectsCurve: [0.34, 0.80, 0.34, 1.0, 1.0, 1.0]

    // -- Pill-expand motion (Axenide/Ambxst). Used by the dashboard to
    //    grow out of the bar's center pill: OutBack (overshoot 1.2) on
    //    open, OutQuart on close.
    property int motionExpandDuration: 360
}
