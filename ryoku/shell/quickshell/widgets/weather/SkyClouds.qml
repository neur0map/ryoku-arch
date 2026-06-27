pragma ComponentBehavior: Bound
import QtQuick

// overcast sky: 2 soft clouds at different depths on one shared drift phase,
// so they don't thrash and they stop cleanly when animation is off. back
// cloud is smaller + fainter for depth.
Item {
    id: sky

    property bool isDay: true
    property bool animate: true

    property real drift: 0
    NumberAnimation on drift {
        running: sky.animate
        from: 0; to: Math.PI * 2; duration: 16000; loops: Animation.Infinite
    }

    Cloud {
        width: sky.width * 0.5
        height: sky.height * 0.34
        y: sky.height * 0.34
        x: sky.width * 0.40 + Math.sin(sky.drift + 1.7) * sky.width * 0.05
        tint: "#cfd6ec"
        solid: 0.7
    }
    Cloud {
        width: sky.width * 0.66
        height: sky.height * 0.44
        y: sky.height * 0.16
        x: sky.width * 0.06 + Math.sin(sky.drift) * sky.width * 0.06
        tint: "#eef2ff"
        solid: 0.95
    }
}
