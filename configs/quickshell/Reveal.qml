import QtQuick

// The one animation every surface opens and closes with. Opening overshoots a
// touch and settles, the way iOS sheets land; closing only accelerates away,
// because an overshoot below zero would briefly map the window again.
NumberAnimation {
    property bool opening

    duration: opening ? Theme.duration.expressiveDefaultSpatial : Theme.duration.expressiveFastSpatial
    easing.type: Easing.BezierSpline
    easing.bezierCurve: opening ? Theme.curve.expressiveDefaultSpatial : Theme.curve.emphasizedAccel
}
