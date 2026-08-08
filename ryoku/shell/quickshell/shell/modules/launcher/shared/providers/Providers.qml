import QtQuick
import "actions"
import "apps"
import "calc"
import "find"
import "media/mpris"
import "packages"
import "radio"
import "recent"
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
    Recent { id: recentProvider }
    Script {}
    Snippets {}
    Web { id: webProvider }
    Windows { id: windowsProvider }

    // exposed so mode bodies can read their provider-owned models directly:
    // action tabs narrow Actions, ALL browses Apps, REC filters Recent, and the
    // AnswerPanel reads Web's async DDG instant answer.
    property alias actions: actionsProvider
    property alias apps: appsProvider
    property alias recent: recentProvider
    property alias web: webProvider
    property alias windows: windowsProvider
}
