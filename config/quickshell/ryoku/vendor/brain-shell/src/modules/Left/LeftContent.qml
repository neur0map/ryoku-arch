import QtQuick
import Quickshell
import "../../components"
import "../../windows"
import "../../"

Row {
	spacing: 5
	// Note: Do NOT add anchors.centerIn: parent here. TopBar handles that.

	// 1. Arch Icon (Power Menu Trigger)
	ControlPanel{}

	// 2. Workspaces
	Workspaces {} 
	
	//3. LayoutDisplay
	LayoutDisplayer {}

}
