import QtQuick
import QtMultimedia 6.0 as Native
import Quickshell

Item {
    id: root
    implicitWidth: videoOut.implicitWidth
    implicitHeight: videoOut.implicitHeight
    
    property var source
    property bool autoPlay: false
    property bool muted: false
    property real volume: 1.0
    property int loops: 1
    property int fillMode: 1 

    Native.VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: root.fillMode
    }

    Native.MediaPlayer {
        id: player
        videoOutput: videoOut
        loops: root.loops
        
        audioOutput: Native.AudioOutput {
            muted: root.muted
            volume: root.volume
        }
        
        onSourceChanged: {
            if (root.autoPlay) {
                player.play();
            }
        }
    }

    onSourceChanged: {
        var str = source ? source.toString() : "";
        if (!str) return;

        if (str.indexOf("QtMultimedia") !== -1 || (!str.startsWith("file://") && !str.startsWith("/"))) {
            var lastSlash = str.lastIndexOf("/");
            var filename = lastSlash >= 0 ? str.substring(lastSlash + 1) : str;
            
            var tName = Quickshell.env("QS_THEME") || "nier-automata";
            var resolvedStr = "file://" + Quickshell.shellDir + "/themes_link/" + tName + "/" + filename;
            
            if (player.source.toString() !== resolvedStr) {
                player.source = resolvedStr;
            }
        } else {
            player.source = source;
        }
    }
    
    onAutoPlayChanged: {
        if (autoPlay && player.source) player.play();
    }

    function play() { player.play(); }
    function pause() { player.pause(); }
    function stop() { player.stop(); }
}
