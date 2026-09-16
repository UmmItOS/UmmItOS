import QtQuick

// Material Symbols renders icon names as ligatures, so `text` is the icon name
// (see fonts.google.com/icons). Matches caelestia's MaterialIcon component.
Text {
    id: root

    // 0 = outline, 1 = filled. Animatable.
    property real fill: 0
    property int grade: -25
    // Own property rather than font.pixelSize: feeding font.pixelSize back into
    // font.variableAxes is a binding loop.
    property int size: Theme.fontSize.large

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
