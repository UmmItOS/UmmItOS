import QtQuick

// The press and hover scale every control shares: standard curve, fast effects duration.
NumberAnimation {
    duration: Theme.duration.expressiveFastEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve.standard
}
