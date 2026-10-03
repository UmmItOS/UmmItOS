import QtQuick
import ".."

MaterialIcon {
    id: root

    required property string icon
    // What it does, for screen readers and the hover tip; English, looked up in I18n.
    property string label
    property color baseColor: Theme.fg
    property color hoverColor: Theme.accent2
    // Only a button that handles rightClicked takes the right button, so others do not press for nothing.
    property bool rightClickable: false

    signal clicked
    signal rightClicked

    text: icon
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t(label)
    Accessible.onPressAction: root.clicked()
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

    Tip {
        anchorItem: root
        text: I18n.t(root.label)
        wanted: mouse.containsMouse && !mouse.pressed
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
