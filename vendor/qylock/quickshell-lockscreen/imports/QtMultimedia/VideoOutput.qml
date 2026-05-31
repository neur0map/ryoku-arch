import QtQuick
import QtMultimedia 6.0 as Native

Native.VideoOutput {
    id: videoOut
    
    // Qt5 fill mode shims
    enum FillMode { 
        Stretch = 0, 
        PreserveAspectFit = 1, 
        PreserveAspectCrop = 2 
    }
}
