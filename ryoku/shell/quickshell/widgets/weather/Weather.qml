pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// weather widget: pick a design, report its size to WidgetSlot. designs read
// forecast / unit / scope / palette from the singletons themselves, so this
// only chooses which to show.
Item {
    id: weather

    readonly property var item: loader.item
    implicitWidth: weather.item ? weather.item.implicitWidth : 1
    implicitHeight: weather.item ? weather.item.implicitHeight : 1

    Loader {
        id: loader
        sourceComponent: weather.designFor(Config.weatherDesign)
    }

    function designFor(d) {
        switch (d) {
        case "minimal": return minimalComp;
        case "strip":   return stripComp;
        default:        return cardComp;
        }
    }

    Component { id: cardComp;    WeatherCard {} }
    Component { id: minimalComp; WeatherMinimal {} }
    Component { id: stripComp;   WeatherStrip {} }
}
