import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import SddmComponents 2.0

Rectangle {
    // Wayland Cursor Fix
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        z: -1
    }
    id: root
    readonly property real s: Screen.height / 768
    width: Screen.width
    height: Screen.height
    color: root.bgColor

    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined

    readonly property string themeMode: config.themeMode || "dark"
    readonly property bool isLight: themeMode === "light"

    // Palette
    readonly property color bgColor:     "#060504"
    readonly property color mainText:    "#e8dcc8"
    readonly property color dimText:     "#5a5040"
    readonly property color accentColor: "#d4a44c"
    readonly property color tapeBg:      "#0c0b09"
    readonly property color tapeBorder:  "#2a2418"
    readonly property color beamColor:   "#d4a44c"
    readonly property color sprocketCol: "#221e15"

    // UI State
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex:    (typeof userModel   !== "undefined" && userModel.lastIndex   >= 0) ? userModel.lastIndex   : 0
    property bool userMenuOpen: false
    property real uiOpacity: 0
    readonly property real marginR: 80 * s

    // Time Logic
    property int curH:  new Date().getHours()
    property int curM:  new Date().getMinutes()
    property int curS:  new Date().getSeconds()
    property int curMS: new Date().getMilliseconds()

    Timer {
        interval: 16; running: true; repeat: true
        onTriggered: { var d = new Date(); root.curH = d.getHours(); root.curM = d.getMinutes(); root.curS = d.getSeconds(); root.curMS = d.getMilliseconds() }
    }

    Component.onCompleted: { fadeIn.start(); keyboard.numLock = true }
    NumberAnimation { id: fadeIn; target: root; property: "uiOpacity"; to: 1; duration: 400; easing.type: Easing.OutCubic }

    // Font Loading
    FolderListModel { id: fontFolder; folder: Qt.resolvedUrl("font"); nameFilters: ["*.ttf", "*.otf"] }
    FontLoader { id: mainFont; source: fontFolder.count > 0 ? "font/" + fontFolder.get(0, "fileName") : "" }
    TextConstants { id: textConstants }

    // Models
    ListView { id: userHelper;    model: typeof userModel    !== "undefined" ? userModel    : null; currentIndex: root.userIndex;    width:1; height:1; opacity:0; delegate: Item { property string uName: model.realName||model.name||""; property string uLogin: model.name||"" } }
    ListView { id: sessionHelper; model: typeof sessionModel !== "undefined" ? sessionModel : null; currentIndex: root.sessionIndex; width:1; height:1; opacity:0; delegate: Item { property string sName: model.name||"" } }
    Timer { interval: 300; running: true; onTriggered: passInput.forceActiveFocus() }

    // Time Frac
    readonly property real s_f: curMS / 1000.0
    readonly property real fracSec:  ((curS + s_f) / 60.0)
    readonly property real m_f: (curS === 59 && s_f > 0.8) ? (function(){ var p = (s_f - 0.8) * 5.0; return p * p * (3 - 2 * p) })() : 0
    readonly property real fracMin:  ((curM + m_f) / 60.0)
    readonly property real h_f: (curM === 59 && curS === 59 && s_f > 0.8) ? (function(){ var p = (s_f - 0.8) * 5.0; return p * p * (3 - 2 * p) })() : 0
    readonly property real fracHour: (((curH % 12) + h_f) / 12.0)

    // Scene
    Item {
        id: sceneRoot
        anchors.fill: parent; opacity: root.uiOpacity

        // Film Strips
        component AmbientStrip: Item {
            id: aStrip
            property real speed: 0.012
            property bool mirrored: false
            clip: true

            readonly property real frameH: 90 * s
            readonly property real stripW: 28 * s
            readonly property real sprW:   10 * s
            readonly property real sprH:    8 * s

            property real stripOffset: 0
            NumberAnimation on stripOffset {
                from: 0; to: 1; duration: (1.0 / aStrip.speed) * 1000
                loops: Animation.Infinite; running: true
            }

            Rectangle { anchors.fill: parent; color: root.tapeBg; opacity: 0.6 }
            Rectangle {
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: aStrip.mirrored ? undefined : parent.right
                anchors.left:  aStrip.mirrored ? parent.left  : undefined; width: 1 * s; color: root.tapeBorder; opacity: 0.5
            }

            Repeater {
                model: Math.ceil(aStrip.height / aStrip.frameH) + 3
                delegate: Item {
                    readonly property real frameY: (index - 1) * aStrip.frameH - (aStrip.stripOffset * aStrip.frameH) + aStrip.frameH * 0.5
                    y: frameY; width: aStrip.stripW; height: aStrip.frameH
                    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1 * s; color: root.tapeBorder; opacity: 0.35 }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: (parent.height - aStrip.sprH) * 0.5; width: aStrip.sprW; height: aStrip.sprH; radius: 2 * s; color: root.sprocketCol; border.color: root.tapeBorder; border.width: 0.5 * s }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 * s; text: String(index * 4 % 100).padStart(2, '0'); font.family: mainFont.name; font.pixelSize: 6 * s; color: root.dimText; opacity: 0.3; rotation: aStrip.mirrored ? 180 : 0 }
                }
            }

            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: parent.height * 0.18; gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 1.0) } GradientStop { position: 1; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.0) } } }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: parent.height * 0.18; gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.0) } GradientStop { position: 1; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 1.0) } } }
        }

        AmbientStrip { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 28 * s; speed: 0.008; mirrored: false; opacity: 0.65 }
        AmbientStrip { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 28 * s; speed: 0.011; mirrored: true; opacity: 0.65 }

        // Vignette
        Rectangle { anchors.fill: parent; z: 0; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0;  color: Qt.rgba(0,0,0, root.isLight ? 0.06 : 0.55) } GradientStop { position: 0.35; color: Qt.rgba(0,0,0,0) } GradientStop { position: 0.65; color: Qt.rgba(0,0,0,0) } GradientStop { position: 1.0;  color: Qt.rgba(0,0,0, root.isLight ? 0.06 : 0.55) } } }

        // Texture
        Item {
            anchors.fill: parent; z: 0; opacity: root.isLight ? 0.025 : 0.04; clip: true
            Repeater { model: Math.ceil(root.height / (4 * s)); delegate: Rectangle { y: index * 4 * s; width: root.width; height: 1 * s; color: "#ffffff" } }
        }

        // Tape Reels
        Item {
            id: clockArea; anchors.left: parent.left; anchors.leftMargin: 80 * s; anchors.verticalCenter: parent.verticalCenter; width: 560 * s; height: 420 * s
            readonly property real tapeW: 128 * s; readonly property real tapeH: parent.height; readonly property real sprW: 14 * s; readonly property real tickH: 60 * s

            // Tape Component
            component TapeReel: Item {
                id: reel; property int tickCount: 60; property real scrollFrac: 0.0; property string unitLabel: "SEC"
                width: clockArea.tapeW; height: clockArea.tapeH; clip: true
                readonly property int curTick: Math.floor(scrollFrac * tickCount); readonly property real subFrac: (scrollFrac * tickCount) - curTick

                // Film Strip
                Rectangle { anchors.fill: parent; color: root.tapeBg; border.color: root.tapeBorder; border.width: 2 * s }
                Rectangle { anchors.fill: parent; opacity: 0.05; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#000000" } GradientStop { position: 0.5; color: "#ffffff" } GradientStop { position: 1; color: "#000000" } } }
                Rectangle { z: 1; anchors.left: parent.left; anchors.right: parent.right; y: reel.height * 0.5 - clockArea.tickH * 0.5; height: clockArea.tickH; color: root.accentColor; opacity: root.isLight ? 0.08 : 0.04 }

                Repeater {
                    id: tickRep; readonly property int modelCount: Math.ceil(reel.height / clockArea.tickH) + 6; readonly property int midIdx: Math.floor(modelCount / 2)
                    model: modelCount
                    delegate: Item {
                        property int tickIdx: ((reel.curTick + index - tickRep.midIdx) % reel.tickCount + reel.tickCount) % reel.tickCount
                        property real offset: reel.subFrac * clockArea.tickH
                        y: (index - tickRep.midIdx) * clockArea.tickH - offset + reel.height * 0.5 - clockArea.tickH * 0.5; width: reel.width; height: clockArea.tickH
                        Repeater { model: 2; delegate: Rectangle { x: 4 * s; y: (index * clockArea.tickH * 0.5) - (height * 0.5); width: clockArea.sprW; height: clockArea.sprW * 0.8; radius: 2 * s; color: root.sprocketCol; border.color: root.tapeBorder; border.width: 0.5 * s } }
                        Text {
                            anchors.centerIn: parent; anchors.horizontalCenterOffset: clockArea.sprW * 0.5; text: String(tickIdx).padStart(2, '0'); font.family: mainFont.name; font.pixelSize: 28 * s; font.weight: Font.DemiBold
                            readonly property real itemCenterY: parent.y + parent.height * 0.5; readonly property real distCenter: Math.abs(itemCenterY - reel.height * 0.5); readonly property real rawRatio: Math.max(0, 1.0 - (distCenter / (clockArea.tickH * 2.0))); readonly property real smoothRatio: rawRatio * rawRatio * (3 - 2 * rawRatio)
                            opacity: 0.18 + (smoothRatio * 0.82); color: Qt.rgba(root.dimText.r + smoothRatio * (root.mainText.r - root.dimText.r), root.dimText.g + smoothRatio * (root.mainText.g - root.dimText.g), root.dimText.b + smoothRatio * (root.mainText.b - root.dimText.b), 1.0)
                        }
                        Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1.5 * s; color: root.tapeBorder; opacity: 0.3 }
                    }
                }
                Rectangle { z: 10; anchors.left: parent.left; anchors.right: parent.right; y: reel.height * 0.5 - clockArea.tickH * 0.5; height: 2 * s; color: root.beamColor; opacity: 1.0 }
                Rectangle { z: 10; anchors.left: parent.left; anchors.right: parent.right; y: reel.height * 0.5 + clockArea.tickH * 0.5; height: 2 * s; color: root.beamColor; opacity: 1.0 }
                Rectangle { z: 11; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: parent.height * 0.32; gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.98) } GradientStop { position: 1; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.0)  } } }
                Rectangle { z: 11; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: parent.height * 0.32; gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.0)  } GradientStop { position: 1; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.98) } } }
                Text { z: 12; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8 * s; text: unitLabel; font.family: mainFont.name; font.pixelSize: 9*s; font.letterSpacing: 3*s; font.weight: Font.Bold; color: root.dimText }
            }

            // Divider
            component TapeDivider: Column { anchors.verticalCenter: parent ? parent.verticalCenter : undefined; spacing: 10 * s; Repeater { model: 5; Rectangle { width: 3*s; height: 3*s; radius: 2*s; color: root.accentColor; opacity: 0.5 } } }

            // Tape Row
            Row { id: tapeRow; anchors.centerIn: parent; spacing: 16 * s
                TapeReel { tickCount: 12; scrollFrac: root.fracHour; unitLabel: "HR" }
                Item { width: 16 * s; height: clockArea.tapeH; TapeDivider { anchors.centerIn: parent } }
                TapeReel { tickCount: 60; scrollFrac: root.fracMin; unitLabel: "MIN" }
                Item { width: 16 * s; height: clockArea.tapeH; TapeDivider { anchors.centerIn: parent } }
                TapeReel { tickCount: 60; scrollFrac: root.fracSec; unitLabel: "SEC" }
            }

            Text { anchors.top: tapeRow.bottom; anchors.topMargin: 20 * s; anchors.horizontalCenter: tapeRow.horizontalCenter; text: Qt.formatDate(new Date(), "dddd  ·  dd MMM yyyy").toUpperCase(); font.family: mainFont.name; font.pixelSize: 11*s; font.letterSpacing: 4*s; color: root.dimText }
            Text { anchors.bottom: tapeRow.top; anchors.bottomMargin: 18 * s; anchors.horizontalCenter: tapeRow.horizontalCenter; text: String(curH).padStart(2,'0') + "  :  " + String(curM).padStart(2,'0') + "  :  " + String(curS).padStart(2,'0'); font.family: mainFont.name; font.pixelSize: 28*s; font.letterSpacing: 6*s; font.weight: Font.Black; color: root.mainText }
        }

        Item {
            id: hudContainer; anchors.fill: parent
            // HUD Bar
            Row {
                anchors.right: parent.right; anchors.rightMargin: root.marginR; anchors.top: parent.top; anchors.topMargin: 50 * s; spacing: 25 * s
                CwAction { visible: !root.isQuickshell; label: sessionHelper.currentItem ? sessionHelper.currentItem.sName : "Session"; onClicked: { if (typeof sessionModel !== "undefined") root.sessionIndex = (root.sessionIndex+1) % sessionModel.rowCount() } }
                Rectangle { visible: !root.isQuickshell; width: 1*s; height: 10*s; color: root.tapeBorder; anchors.verticalCenter: parent.verticalCenter }
                CwAction { label: "Reboot";   onClicked: { if (typeof sddm !== "undefined") sddm.reboot()   } }
                Rectangle { width: 1*s; height: 10*s; color: root.tapeBorder; anchors.verticalCenter: parent.verticalCenter }
                CwAction { label: "Shutdown"; onClicked: { if (typeof sddm !== "undefined") sddm.powerOff() } }
            }
            // Login Panel
            Item {
                id: loginPanel; anchors.right: parent.right; anchors.rightMargin: root.marginR; anchors.bottom: parent.bottom; anchors.bottomMargin: 72 * s; width: 320 * s; height: terminalCol.height + 48 * s
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.tapeBorder; border.width: 1.5 * s; opacity: 0.6 }
                Item {
                    id: sideStrip; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; width: 22 * s; clip: true
                    Rectangle { anchors.fill: parent; color: root.tapeBg; opacity: 0.5 }
                    Rectangle { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; width: 1*s; color: root.tapeBorder; opacity: 0.4 }
                    Repeater { model: Math.ceil(loginPanel.height / (32 * s)); delegate: Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12 * s + index * 32 * s; width: 10 * s; height: 8 * s; radius: 2 * s; color: root.sprocketCol; border.color: root.tapeBorder; border.width: 0.5 * s } }
                }

                Column {
                    id: terminalCol; anchors.left: sideStrip.right; anchors.leftMargin: 20 * s; anchors.right: parent.right; anchors.rightMargin: 20 * s; anchors.top: parent.top; anchors.topMargin: 24 * s; spacing: 0
                    Item { width: 1; height: 4*s }
                    // User
                    Item {
                        width: parent.width; height: 36*s
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "USER"; font.family: mainFont.name; font.pixelSize: 7*s; font.letterSpacing: 3*s; font.weight: Font.Bold; color: root.accentColor; opacity: 0.55 }
                        Text { id: userNameDisp2; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: uMa2.containsMouse ? 20*s : 0; text: ((userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : ((typeof userModel !== "undefined" && userModel.lastUser) ? capitalizeFirst(userModel.lastUser) : "USER")).toUpperCase(); font.family: mainFont.name; font.pixelSize: 14*s; font.letterSpacing: 4*s; font.weight: Font.Bold; color: uMa2.containsMouse ? root.mainText : root.dimText; Behavior on color { ColorAnimation { duration: 200 } } Behavior on anchors.rightMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
                        Text { anchors.left: userNameDisp2.right; anchors.leftMargin: 6*s; anchors.verticalCenter: userNameDisp2.verticalCenter; text: "✦"; font.family: mainFont.name; font.pixelSize: 10*s; color: root.mainText; opacity: uMa2.containsMouse ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } }
                        MouseArea { id: uMa2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (typeof userModel !== "undefined") root.userIndex = (root.userIndex + 1) % userModel.rowCount() } }
                    }
                    Rectangle { width: parent.width; height: 1*s; color: root.tapeBorder; opacity: 0.25 }
                    Item { width: 1; height: 14*s }
                    // Password
                    Text { width: parent.width; text: "PASSWORD"; font.family: mainFont.name; font.pixelSize: 7*s; font.letterSpacing: 3*s; font.weight: Font.Bold; color: root.accentColor; opacity: 0.55 }
                    Item { width: 1; height: 6*s }
                    Item {
                        width: parent.width; height: 36*s
                        Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1.5*s; color: root.accentColor; opacity: 0.5 }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1.5*s; color: root.tapeBorder; opacity: 0.35 }
                        TextInput {
                            id: passInput; anchors.fill: parent; anchors.leftMargin: 4*s; anchors.rightMargin: 4*s; echoMode: TextInput.Password; passwordCharacter: "■"; color: root.mainText; font.family: mainFont.name; font.pixelSize: 13*s; font.letterSpacing: 8*s; horizontalAlignment: TextInput.AlignLeft; verticalAlignment: TextInput.AlignVCenter; focus: true; cursorVisible: false; cursorDelegate: Item { width:0; height:0 }
                            property bool wasClicked: false; Keys.onReturnPressed: startLoginSequence()
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "WAITING FOR KEY"; font.family: mainFont.name; font.pixelSize: 9*s; font.letterSpacing: 4*s; color: root.dimText; opacity: passInput.text.length===0 ? 0.45 : 0; Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutSine } } }
                            Rectangle {
                                id: needleCursor2; width: 1.5*s; height: 14*s; color: root.accentColor; anchors.verticalCenter: parent.verticalCenter; x: passInput.cursorRectangle.x; visible: passInput.focus && (passInput.text.length>0 || passInput.wasClicked)
                                SequentialAnimation { loops: Animation.Infinite; running: needleCursor2.visible; NumberAnimation { target: needleCursor2; property: "opacity"; from: 1; to: 0; duration: 500 } NumberAnimation { target: needleCursor2; property: "opacity"; from: 0; to: 1; duration: 500 } }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; onClicked: { passInput.forceActiveFocus(); passInput.wasClicked = true } }
                    }
                    Item { width: 1; height: 14*s }
                    // Login Button
                    Item {
                        width: parent.width; height: 28*s; opacity: passInput.text.length > 0 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300 } }
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "▶"; font.family: mainFont.name; font.pixelSize: 8*s; color: root.accentColor; opacity: btnMa2.containsMouse ? 1.0 : 0.4; Behavior on opacity { NumberAnimation { duration: 200 } } }
                        Text { id: loginBtn2; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "ENTER KEY"; font.family: mainFont.name; font.pixelSize: 10*s; font.letterSpacing: 5*s; font.weight: Font.Bold; color: btnMa2.containsMouse ? root.mainText : root.dimText; Behavior on color { ColorAnimation { duration: 200 } } }
                        MouseArea { id: btnMa2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: startLoginSequence() }
                    }
                    Item { width: 1; height: 8*s }
                    Text { id: errText; width: parent.width; horizontalAlignment: Text.AlignRight; text: ""; color: "#cc4444"; font.family: mainFont.name; font.pixelSize: 9*s; font.letterSpacing: 3*s }
                    Item { width: 1; height: 4*s }
                }
            }
        }
    }


    function startLoginSequence() {
        if (passInput.text.length===0) return
        doLogin()
    }
    function doLogin() { var uname = (userHelper.currentItem&&userHelper.currentItem.uLogin)?userHelper.currentItem.uLogin:(typeof userModel!=="undefined"?userModel.lastUser:"user"); if (typeof sddm!=="undefined") sddm.login(uname, passInput.text, root.sessionIndex) }
    function capitalizeFirst(str) { if (!str) return ""; return str.charAt(0).toUpperCase()+str.slice(1) }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginSucceeded() { }
        function onLoginFailed() { errText.text="ACCESS DENIED"; passInput.text=""; passInput.forceActiveFocus(); shake.start() }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; from: root.marginR; to: root.marginR+10*s; duration: 50; easing.type: Easing.InOutSine }
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; to: root.marginR-10*s; duration: 50; easing.type: Easing.InOutSine }
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; to: root.marginR;      duration: 50; easing.type: Easing.InOutSine }
    }

    component CwAction: Item {
        id: actItem; width: actTxt.width+20*s; height: 15*s; property string label: ""; signal clicked()
        Text { id: actTxt; anchors.right: parent.right; anchors.rightMargin: actM.containsMouse?15*s:0; text: label.toUpperCase(); color: actM.containsMouse?root.mainText:root.dimText; font.family: mainFont.name; font.pixelSize: 10*s; font.letterSpacing: 3*s; Behavior on color { ColorAnimation { duration: 200 } }  Behavior on anchors.rightMargin { NumberAnimation { duration: 200 } } }
        Text { text: "✦"; anchors.left: actTxt.right; anchors.leftMargin: 4*s; anchors.verticalCenter: actTxt.verticalCenter; color: root.mainText; opacity: actM.containsMouse?1:0; font.pixelSize: 8*s; Behavior on opacity { NumberAnimation { duration: 200 } } }
        MouseArea { id: actM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actItem.clicked() }
    }
}
