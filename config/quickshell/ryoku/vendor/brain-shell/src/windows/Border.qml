import Quickshell
import QtQuick
import "../"
import "../services/"

PanelWindow {
    id: root

    property string edge: "bottom"
    property bool isBarEnabled: Theme.barEnabled
    property int thickness: Theme.borderWidth      
    property int radius: Theme.cornerRadius        
    property color fillColor: Theme.background 
    
    implicitWidth: (edge === "left" || edge === "right") ? radius : 0
    implicitHeight: (edge === "bottom") ? radius : 0

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        left: (edge === "left" || edge === "bottom")
        right: (edge === "right" || edge === "bottom")
        bottom: true
        top: (edge !== "bottom")
    }

    margins {
        top: (edge !== "bottom") ? ShellState.focusMode ? Theme.borderWidth : Theme.notchHeight: 0
        Behavior on top { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }}
        
        bottom: (edge !== "bottom") ? radius : 0
    }

    Item {
        anchors.fill: parent

        Canvas {
            id: shape
            anchors.fill: parent
            
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: root
                function onFillColorChanged() { shape.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.fillColor;
                ctx.beginPath();

                var w = width;
                var h = height;
                var t = root.thickness;
                var r = root.radius;

                if (root.edge === "left") {
                    // == LEFT BORDER (Top Melt) ==
                
                // 1. Top-Left (Outer Corner) - Touches the notch
                    ctx.moveTo(0, 0); 
                
                // 2. Top-Right "Flare" (The Melt Connection)
                // Extends out along the notch bottom, then curves in
                    ctx.lineTo(t + r, 0); 
                
                // Curve Inwards to the vertical strip
                // Control Point: (t, 0) -> The inner corner
                // End Point: (t, r) -> Start of straight line
                    ctx.arcTo(t, 0, t, r, r);
                
                // 3. Vertical Strip Down
                    ctx.lineTo(t, h);
                
                // 4. Close Left Edge
                    ctx.lineTo(0, h);
                    ctx.lineTo(0, 0);
                } 
                else if (root.edge === "right") {
                    // == RIGHT BORDER (Top Melt) ==
                
                // 1. Top-Right (Outer Corner)
                    ctx.moveTo(w, 0);
                
                // 2. Top-Left "Flare"
                    ctx.lineTo(w - (t + r), 0);
                
                // Curve Inwards
                    ctx.arcTo(w - t, 0, w - t, r, r);
                
                // 3. Vertical Strip Down
                    ctx.lineTo(w - t, h);
                
                // 4. Close Right Edge
                    ctx.lineTo(w, h);
                    ctx.lineTo(w, 0);
                }
                else if (root.edge === "bottom") {
                // == BOTTOM BORDER ==
                
                // 1. Outer Bottom-Left Corner (SQUARE)
                    ctx.moveTo(0, 0);       
                    ctx.lineTo(0, h);       
                    ctx.lineTo(w, h);       
                    ctx.lineTo(w, 0);       
                
                // 2. Inner Right Corner (ROUNDED)
                    ctx.lineTo(w - t, 0);   
                    ctx.arcTo(w - t, h - t, w - t - r, h - t, r);
                
                // 3. Inner Bottom Line
                    ctx.lineTo(t + r, h - t);
                
                // 4. Inner Left Corner (ROUNDED)
                    ctx.arcTo(t, h - t, t, 0, r);
                
                // 5. Close Loop
                    ctx.lineTo(t, 0);
                    ctx.lineTo(0, 0);
                }

                ctx.fill();
            }
        }

        // ── Left border — hover opens ArchMenu ────────────────────────────────
        Item {
            visible: root.edge === "left"
            anchors{
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
            }
            height: 300
            HoverHandler {
                enabled: root.edge === "left"
                onHoveredChanged: Popups.archMenuTriggerHovered = hovered
            }
        }

        // ── Right border — hover opens AudioPopup ─────────────────────────────
        Item {
            visible: root.edge === "right"
            anchors{
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
            }
            height: 300
            HoverHandler {
                enabled: root.edge === "right"
                onHoveredChanged: {
                    Popups.quickTriggerHovered = hovered  
                    Popups.audioTriggerHovered = hovered
                }
            }
        }


        // ── Bottom border — centered region only, click + hover for wallpaper ─
        // Only a fixed-width centered strip triggers the wallpaper popup.
        // Full-width taps on the rest of the border do nothing.
        Item {
            visible:                  root.edge === "bottom"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:              parent.top
            anchors.bottom:           parent.bottom
            width:                    420

            HoverHandler {
                onHoveredChanged: Popups.wallpaperTriggerHovered = hovered
            }

            TapHandler {
                onTapped: Popups.wallpaperOpen = !Popups.wallpaperOpen
            }
        }
    }
}
