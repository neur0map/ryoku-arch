import QtQuick
import "actions"
import "apps"
import "calc"
import "clipboard"
import "files"
import "media/mpris"
import "media/ytmusic"
import "packages"
import "snippets"
import "web"
import "windows"

// Instantiates every launcher provider so each registers itself with the
// dispatcher on load. Adding a provider is one import + one line here; the
// dispatcher discovers it by registration, never by an edit to the routing.
Item {
    id: providers
    Actions { id: actionsProvider }
    Apps {}
    Calc {}
    Clipboard {}
    Files {}
    Mpris {}
    YtMusic {}
    Packages {}
    Snippets {}
    Web {}
    Windows {}

    // exposed so the action-mode tabs can narrow the actions provider's list.
    property alias actions: actionsProvider
}
