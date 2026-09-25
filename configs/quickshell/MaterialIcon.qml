import QtQuick

// Material Symbols ligatures: `text` is the icon name.
Text {
    id: root

    // 0 = outline, 1 = filled. Animatable.
    property real fill: 0
    property int grade: -25
    // Not font.pixelSize: feeding it to variableAxes is a binding loop.
    property int size: Theme.icon.normal

    font.family: "Material Symbols Rounded"
    font.pixelSize: root.size
    font.variableAxes: ({
            FILL: root.fill.toFixed(1),
            GRAD: root.grade,
            opsz: root.size,
            wght: 400
        })

    Behavior on fill {
        NumberAnimation {
            duration: Theme.duration.expressiveFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }
    }
}
