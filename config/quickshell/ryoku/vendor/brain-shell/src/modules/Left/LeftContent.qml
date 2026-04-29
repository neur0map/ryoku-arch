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
	
	// Ryoku Patch 9: LayoutDisplayer removed from the bar.
	// Upstream's display-only indicator shipped placeholder-text returns
	// (><, M, bracketed counts) that look like a broken button. The
	// LayoutDisplayer.qml file stays vendored for future re-introduction
	// as a clickable layout-switcher widget (see docs/TODO.md Spec 2.5).
	// LayoutDisplayer {}

}
