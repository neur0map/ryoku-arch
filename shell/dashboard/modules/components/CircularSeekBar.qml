import QtQuick
import QtQuick.Shapes
import qs.dashboard.config
import qs.dashboard.modules.theme

Item {
    id: root


    property real value: 0
    property real startAngleDeg: 180
    property real spanAngleDeg: 180
    
    property color accentColor: Colors.primary
    property color trackColor: Colors.outline
    
    property real lineWidth: 6
    property real ringPadding: 12
    
    property bool enabled: true
    property bool dashed: false
    property bool dashedActive: false
    
    property bool wavy: false
    property real waveAmplitude: 0
    property real waveFrequency: 0


    signal valueEdited(real newValue)
    signal draggingChanged(bool dragging)


    readonly property bool isDragging: mouseArea.isDragging
    property real dragValue: 0
    
    property real animatedHandleOffset: isDragging ? 9 : 6
    property real animatedHandleWidth: isDragging ? lineWidth * 0.5 : lineWidth
    Behavior on animatedHandleOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on animatedHandleWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    property real dotSize: lineWidth
    property real baseDashLength: dotSize * 2.5
    property real targetSpacing: 6
    
    
    property real currentDashLen: dashedActive ? baseDashLength : (baseDashLength + targetSpacing)
    property real currentGapLen: dashedActive ? targetSpacing : 0
    
    Behavior on currentDashLen { NumberAnimation { duration: Config.animDuration; easing.type: Easing.InOutQuad } }
    Behavior on currentGapLen { NumberAnimation { duration: Config.animDuration; easing.type: Easing.InOutQuad } }

    property real phase: 0
    readonly property real cycleLength: baseDashLength + targetSpacing
    
    NumberAnimation on phase {
        running: (root.dashedActive || root.wavy) && root.visible
        from: 0
        to: -root.cycleLength
        duration: 1000
        loops: Animation.Infinite
    }

    property real wavePhase: 0
    
    Timer {
        id: waveTimer
        interval: 32
        running: root.wavy && root.visible && (root.value > 0 || root.isDragging)
        repeat: true
        onTriggered: {
            root.wavePhase = (root.wavePhase + 0.1) % (Math.PI * 2)
        }
    }

    readonly property real radius: (Math.min(width, height) / 2) - ringPadding
    readonly property real effectiveValue: isDragging ? dragValue : value
    
    property real handleSpacing: 10 
    
    readonly property real gapAngleRad: (handleSpacing / 2) / Math.max(1, radius)
    readonly property real gapAngleDeg: gapAngleRad * 180 / Math.PI
    
    readonly property real currentAngleRad: (startAngleDeg + (spanAngleDeg * effectiveValue)) * Math.PI / 180

    readonly property real waveOffsetAtHandle: 0 
    readonly property real effectiveRadiusAtHandle: root.radius

    function generateWavyArcPoints(startDeg, endDeg, phase) {
        if (phase === undefined) phase = 0;
        
        if (startDeg >= endDeg - 0.1) return [];

        let points = [];
        let step = 0.5;
        
        let centerX = root.width / 2;
        let centerY = root.height / 2;
        let baseR = root.radius;
        let waveFreq = root.waveFrequency;
        let waveAmp = root.waveAmplitude;

        for (let angleDeg = startDeg; angleDeg <= endDeg + 0.001; angleDeg += step) {
             let clampedDeg = Math.min(angleDeg, endDeg);
             let angleRad = clampedDeg * Math.PI / 180;
             
             let waveOffset = Math.sin((angleRad * waveFreq) + phase) * waveAmp;
             let r = baseR + waveOffset;
             
             points.push(Qt.point(centerX + r * Math.cos(angleRad), centerY + r * Math.sin(angleRad)));
             
             if (clampedDeg >= endDeg) break;
        }
        return points;
    }



    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        preventStealing: true
        
        property bool isDragging: false

        function updateValueFromMouse(mouseX, mouseY) {
            let centerX = width / 2;
            let centerY = height / 2;
            let angle = Math.atan2(mouseY - centerY, mouseX - centerX);
            if (angle < 0) angle += 2 * Math.PI;

            let startRad = root.startAngleDeg * Math.PI / 180;
            let spanRad = root.spanAngleDeg * Math.PI / 180;
            
            let relAngle = angle - startRad;
            while (relAngle < 0) relAngle += 2 * Math.PI;
            
            let progress = 0;
            if (relAngle <= spanRad) {
                progress = relAngle / spanRad;
            } else {
                let distToEnd = relAngle - spanRad;
                let distToStart = 2 * Math.PI - relAngle;
                progress = (distToEnd < distToStart) ? 1.0 : 0.0;
            }
            
            root.dragValue = progress;
        }

        onPressed: mouse => {
            isDragging = true;
            root.dragValue = root.value;
            root.draggingChanged(true);
            updateValueFromMouse(mouse.x, mouse.y);
        }

        onPositionChanged: mouse => {
            if (isDragging) updateValueFromMouse(mouse.x, mouse.y);
        }

        onReleased: {
            if (isDragging) {
                isDragging = false;
                root.draggingChanged(false);
                root.valueEdited(root.dragValue);
            }
        }
    }



    Shape {
        id: shapeRenderer
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: (!root.wavy) ? root.accentColor : "transparent"
            strokeWidth: root.lineWidth
            
            strokeStyle: root.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            dashPattern: [
                Math.max(0.001, root.currentDashLen / root.lineWidth),
                Math.max(0.001, root.currentGapLen / root.lineWidth)
            ]
            dashOffset: root.phase / root.lineWidth
            
            fillColor: "transparent"
            
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngleDeg
                sweepAngle: Math.max(0, (root.spanAngleDeg * root.effectiveValue) - root.gapAngleDeg)
            }
        }

        ShapePath {
            strokeColor: root.wavy ? root.accentColor : "transparent"
            strokeWidth: root.lineWidth
            
            strokeStyle: root.dashed ? ShapePath.DashLine : ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            dashPattern: [
                Math.max(0.001, root.currentDashLen / root.lineWidth),
                Math.max(0.001, root.currentGapLen / root.lineWidth)
            ]
            dashOffset: root.phase / root.lineWidth
            
            fillColor: "transparent"
            
            startX: wavyProgressPoly.path.length > 0 ? wavyProgressPoly.path[0].x : 0
            startY: wavyProgressPoly.path.length > 0 ? wavyProgressPoly.path[0].y : 0

            PathPolyline {
                id: wavyProgressPoly
                path: root.generateWavyArcPoints(
                    root.startAngleDeg, 
                    root.startAngleDeg + Math.max(0, (root.spanAngleDeg * root.effectiveValue) - root.gapAngleDeg),
                    root.wavePhase
                )
            }
        }

        ShapePath {
            strokeColor: (!root.wavy) ? root.trackColor : "transparent"
            strokeWidth: root.lineWidth
            strokeStyle: ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            
            fillColor: "transparent"
            
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngleDeg + (root.spanAngleDeg * root.effectiveValue) + root.gapAngleDeg
                sweepAngle: Math.max(0, (root.spanAngleDeg * (1.0 - root.effectiveValue)) - root.gapAngleDeg)
            }
        }

        ShapePath {
            strokeColor: root.wavy ? root.trackColor : "transparent"
            strokeWidth: root.lineWidth
            strokeStyle: ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngleDeg + (root.spanAngleDeg * root.effectiveValue) + root.gapAngleDeg
                sweepAngle: Math.max(0, (root.spanAngleDeg * (1.0 - root.effectiveValue)) - root.gapAngleDeg)
            }
        }
        
        ShapePath {
            strokeColor: Colors.overBackground
            strokeWidth: root.animatedHandleWidth
            strokeStyle: ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            
            fillColor: "transparent"
            
            
            startX: (root.width / 2) + (root.effectiveRadiusAtHandle - root.animatedHandleOffset) * Math.cos(root.currentAngleRad)
            startY: (root.height / 2) + (root.effectiveRadiusAtHandle - root.animatedHandleOffset) * Math.sin(root.currentAngleRad)
            
            PathLine {
                x: (root.width / 2) + (root.effectiveRadiusAtHandle + root.animatedHandleOffset) * Math.cos(root.currentAngleRad)
                y: (root.height / 2) + (root.effectiveRadiusAtHandle + root.animatedHandleOffset) * Math.sin(root.currentAngleRad)
            }
        }
    }
}
