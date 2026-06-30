import QtQuick
import "apps"
import "calc"
import "packages"
import "snippets"
import "web"

// Instantiates every launcher provider so each registers itself with the
// dispatcher on load. Adding a provider is one import + one line here; the
// dispatcher discovers it by registration, never by an edit to the routing.
Item {
    Apps {}
    Calc {}
    Packages {}
    Snippets {}
    Web {}
}
