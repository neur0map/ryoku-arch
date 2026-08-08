pragma Singleton
import QtQuick
import "BarCatalog.js" as Lib

// The fixed catalog of rail bar widgets and the axes each one fits. Wrapped as
// an installed-module singleton so FrameBars.normalize() reaches entry() the
// same way from any config root.
QtObject {
    function ids() { return Lib.ids(); }
    function entry(id) { return Lib.entry(id); }
}
