import QtQuick
import "actions"
import "apps"
import "calc"
import "find"
import "media/mpris"
import "packages"
import "radio"
import "script"
import "snippets"
import "web"
import "windows"

// Instantiates every launcher provider so each registers itself with the
// dispatcher on load. Adding a provider is one import + one line here; the
// dispatcher discovers it by registration, never by an edit to the routing.
Item {
    id: providers
    Actions { id: actionsProvider }
    Apps { id: appsProvider }
    Calc {}
    Find {}
    Mpris {}
    Packages {}
    RadioTuner {}
    Script {}
    Snippets {}
    Web { id: webProvider }
    Windows {}

    // exposed so the action-mode tabs can narrow the actions provider's list,
    // the all-apps grid can read the full app list, and the launcher can read
    // the web provider's async DDG instant answer for the AnswerPanel.
    property alias actions: actionsProvider
    property alias apps: appsProvider
    property alias web: webProvider
}
