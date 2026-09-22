import QtQuick
import ".."

MaterialIcon {
    id: root

    required property string icon
    property color baseColor: Theme.fg

    signal clicked

    text: icon
    color: mouse.containsMouse ? Theme.accent2 : baseColor
    fill: mouse.containsMouse ? 1 : 0

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.expressiveFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -Theme.spacing.extraSmall
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
