pragma ComponentBehavior: Bound
import QtQuick

// animated sky backdrop: pick the right animation for the current category,
// fill parent. designs drop one behind their readout at whatever size; flip
// `animate` off to freeze it for a still preview or an inhibited desktop.
Item {
    id: sky

    property string category: "clouds"
    property bool isDay: true
    property bool animate: true

    Loader {
        anchors.fill: parent
        sourceComponent: sky.pick()
    }

    function pick() {
        switch (sky.category) {
        case "clear": return clearC;
        case "rain":  return rainC;
        case "snow":  return snowC;
        case "storm": return stormC;
        case "fog":   return fogC;
        default:      return cloudsC;
        }
    }

    Component { id: clearC;  SkyClear  { isDay: sky.isDay; animate: sky.animate } }
    Component { id: cloudsC; SkyClouds { isDay: sky.isDay; animate: sky.animate } }
    Component { id: rainC;   SkyRain   { animate: sky.animate } }
    Component { id: snowC;   SkySnow   { animate: sky.animate } }
    Component { id: stormC;  SkyStorm  { animate: sky.animate } }
    Component { id: fogC;    SkyFog    { animate: sky.animate } }
}
