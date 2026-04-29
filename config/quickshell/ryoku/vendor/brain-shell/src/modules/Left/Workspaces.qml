import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../"

Rectangle {
    id: root

    // --- 1. Capsule Container ---
    color: Theme.wsBackground
    radius: Theme.wsRadius

    // Auto-size
    width: workspaceRow.width + (Theme.wsPadding * 2)
    height: Theme.wsDotSize + (Theme.wsPadding * 2)

    // --- 2. LOGIC: Raw Event Listener ---
    property bool isScratchpad: false
    
    property bool scrollBusy: false

    Timer {
        id: scrollCooldown
        interval: 300   // ms — tune up if still too fast, down if sluggish
        repeat:   false
        onTriggered: root.scrollBusy = false
    }
    
    // ---Wheel: cycle through occupied workspaces ---
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (root.scrollBusy) return; // Ignore if still in cooldown
            root.scrollBusy = true;
            scrollCooldown.restart();
            // Fetch and sort occupied workspace IDs numerically
            let occupied = Hyprland.workspaces.values.map(w => w.id).sort((a, b) => a - b);
            if (occupied.length === 0) return; // Safety check

            let currentId = Hyprland.focusedWorkspace?.id || occupied[0];
            let idx = occupied.indexOf(currentId);
            if (idx === -1) idx = 0; // Fallback if current isn't in the array

            // Inverted scroll logic: Up (>0) goes to Next, Down (<0) goes to Prev
            if (event.angleDelta.y < 0) {
                idx = (idx + 1) % occupied.length;
            } else {
                idx = (idx - 1 + occupied.length) % occupied.length;
            }
            
            Hyprland.dispatch(`workspace ${occupied[idx]}`);
        }
    }   
    Connections {
        target: Hyprland
        
        // Quickshell emits (name, data) for raw events
        function onRawEvent(event) {
		//	console.log("RawEvent_name: "+ event.name)
		//	console.log("RawEvent_data: "+ event.data)
            // 1. Handle Scratchpad Toggle
            if (event.name === "activespecial") {
                // Event data format: "workspaceName,monitorName"
                // Example: "special:magic,eDP-1" or ",eDP-1" (closed)
                const wsName = event.data.split(',')[0];
                
                // If name is not empty, scratchpad is open.
                root.isScratchpad = (wsName !== "");
            }
            
            // 2. Reset when switching to a normal workspace
            if (event.name === "destroyworkspace") {
                root.isScratchpad = false;
            }
        }
    }

    // --- 3. Workspace Dots ---
    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: Theme.wsSpacing

        // Logic: Fade out dots when Scratchpad is active
        opacity: root.isScratchpad ? 0 : 1
        scale:   root.isScratchpad ? 0.8 : 1
        visible: opacity > 0 

        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale   { NumberAnimation { duration: 200 } }

        Repeater {
            model: 10 
            delegate: Rectangle {
                id: dot
                
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                property bool isOccupied: ws !== undefined
                property bool isUrgent:   ws !== undefined && ws.urgent


                height: Theme.wsDotSize
                radius: height / 2
                width: isActive ? Theme.wsActiveWidth : Theme.wsDotSize
                
                color: {
                    if (isActive)   return Theme.wsActive
                    if (isUrgent)   return Theme.wsUrgent
                    if (isOccupied) return Theme.wsOccupied
                    return Theme.wsEmpty
                }

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 200 } }

                // --- Urgent pulse ---
                SequentialAnimation {
                    running: dot.isUrgent && !dot.isActive
                    loops:   Animation.Infinite

                    NumberAnimation {
                        target:   dot
                        property: "scale"
                        to:       1.35
                        duration: 400
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target:   dot
                        property: "scale"
                        to:       1.0
                        duration: 400
                        easing.type: Easing.InOutSine
                    }
                }

                // Reset scale when no longer urgent
                onIsUrgentChanged: {
                    if (!isUrgent) scale = 1.0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${index + 1}`)
                }
            }
        }
    }

    // --- 4. Scratchpad Overlay ---
    Rectangle {
        id: overlay
        anchors.fill: parent
        radius: root.radius
        color: Theme.wsOverlay
        z: 99
        
        // Logic: Fade in overlay when Scratchpad is active
        visible: opacity > 0
        opacity: root.isScratchpad ? 1 : 0
        
        Behavior on opacity { NumberAnimation { duration: 200 } }
        
        Text {
            anchors.centerIn: parent
            text: "" 
            color: "#FFFFFF"
            font.pixelSize: 14
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: Hyprland.dispatch("togglespecialworkspace magic")
        }
    }
}
