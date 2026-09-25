import QtQuick

// Closing never overshoots: below zero would map the window again.
NumberAnimation {
    property bool opening

    duration: opening ? Theme.duration.expressiveDefaultSpatial : Theme.duration.expressiveFastSpatial
    easing.type: Easing.BezierSpline
    easing.bezierCurve: opening ? Theme.curve.expressiveDefaultSpatial : Theme.curve.emphasizedAccel
}
