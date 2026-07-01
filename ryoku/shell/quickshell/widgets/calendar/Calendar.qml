pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// calendar widget: pick a design, report its size to WidgetSlot. designs read
// the event store, week start, palette and size knobs from the singletons
// themselves, so this only chooses which to show and lays it out. `editing` is
// bubbled up from the active face (true while its add field holds focus) so the
// wallpaper layer can grab the keyboard for typing, the way plugin tiles do.
Item {
    id: calendar

    readonly property var item: loader.item
    readonly property bool editing: !!(calendar.item && calendar.item.editing)

    implicitWidth: calendar.item ? calendar.item.implicitWidth : 1
    implicitHeight: calendar.item ? calendar.item.implicitHeight : 1

    Loader {
        id: loader
        sourceComponent: calendar.designFor(Config.calDesign)
    }

    function designFor(d) {
        switch (d) {
        case "minimal": return minimalComp;
        case "agenda":  return agendaComp;
        case "week":    return weekComp;
        case "heat":    return heatComp;
        default:        return monthComp;
        }
    }

    Component { id: monthComp;   CalMonth {} }
    Component { id: minimalComp; CalMinimal {} }
    Component { id: agendaComp;  CalAgenda {} }
    Component { id: weekComp;    CalWeek {} }
    Component { id: heatComp;    CalHeat {} }
}
