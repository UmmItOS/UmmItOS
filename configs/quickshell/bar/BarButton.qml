import QtQuick
import ".."

MaterialIcon {
    id: root

    required property string icon
    property color baseColor: Theme.fg
    property color hoverColor: Theme.accent2
    // Only a button that handles rightClicked takes the right button, so others do not press for nothing.
    property bool rightClickable: false

    signal clicked
    signal rightClicked

    text: icon
    color: mouse.containsMouse ? hoverColor : baseColor
    fill: mouse.containsMouse ? 1 : 0
    scale: mouse.pressed ? Theme.pressScale : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.duration.expressiveFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }
    }

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
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.rightClickable ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
